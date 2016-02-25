# encoding: utf-8

require 'ting_yun/agent/database'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/support/coerce'
require 'ting_yun/metrics/stats'
require 'ting_yun/support/helper'
module TingYun
  module Agent
    module Collector
      # This class contains the logic of recording slow SQL traces, which may
      # represent multiple aggregated SQL queries.
      #
      # A slow SQL trace consists of a collection of SQL instrumented SQL queries
      # that all normalize to the same text. For example, the following two
      # queries would be aggregated together into a single slow SQL trace:
      #
      #   SELECT * FROM table WHERE id=42
      #   SELECT * FROM table WHERE id=1234
      #
      # Each slow SQL trace keeps track of the number of times the same normalized
      # query was seen, the min, max, and total time spent executing those
      # queries, and an example backtrace from one of the aggregated queries.
      #
      class SqlSampler

        MAX_SAMPLES = 10

        attr_reader :sql_traces

        def initialize
          @sql_traces = {}
          @samples_lock = Mutex.new
        end

        def enabled?
          Agent.config[:'nbs.action_tracer.enabled'] &&
              Agent.config[:'nbs.action_tracer.slow_sql'] &&
                  TingYun::Agent::Database.should_record_sql?('nbs.action_tracer.record_sql')
        end

        def on_start_transaction(state, uri=nil)
          return unless enabled?

          state.sql_sampler_transaction_data = TransactionSqlData.new

          if Agent.config[:'nbs.action_tracer.slow_sql'] && state.sql_sampler_transaction_data
            state.sql_sampler_transaction_data.set_transaction_info(uri)
          end
        end

        def notice_sql(sql, metric_name, config, duration, state=nil, explainer=nil) #THREAD_LOCAL_ACCESS sometimes
          start_time = Time.now.to_f
          state ||= TingYun::Agent::TransactionState.tl_get
          data = state.sql_sampler_transaction_data
          return unless data

          if state.is_sql_recorded? && !metric_name.nil?
            if duration*1000 > TingYun::Agent.config[:'nbs.action_tracer.slow_sql_threshold']
              backtrace = caller.join("\n")
              statement = TingYun::Agent::Database::Statement.new(sql, config, explainer)
              data.sql_data << SlowSql.new(statement, metric_name, duration, start_time, backtrace)
            end
          end
        end


        def on_finishing_transaction(state, name)
          return unless enabled?

          transaction_sql_data = state.sql_sampler_transaction_data
          return unless transaction_sql_data

          transaction_sql_data.set_transaction_name(name)

          save_slow_sql(transaction_sql_data)
        end

        def save_slow_sql(data)
          if data.sql_data.size > 0
            @samples_lock.synchronize do
              ::TingYun::Agent.logger.debug "Examining #{data.sql_data.size} slow transaction sql statement(s)"
              save data
            end
          end
        end

        def save (transaction_sql_data)
          action_metric_name = transaction_sql_data.action_metric_name
          uri                = transaction_sql_data.uri

          transaction_sql_data.sql_data.each do |sql_item|
            normalized_sql = sql_item.normalize
            sql_trace = @sql_traces[normalized_sql]
            if sql_trace
              sql_trace.aggregate(sql_item, action_metric_name, uri)
            else
              if has_room?
                sql_trace = SqlTrace.new(normalized_sql, sql_item, action_metric_name, uri)
              elsif should_add_trace?(sql_item)
                remove_shortest_trace
                sql_trace = SqlTrace.new(normalized_sql, sql_item, action_metric_name, uri)
              end

              if sql_trace
                @sql_traces[normalized_sql] = sql_trace
              end

            end
          end
        end

        # this should always be called under the @samples_lock
        def has_room?
          @sql_traces.size < MAX_SAMPLES
        end

        # this should always be called under the @samples_lock
        def should_add_trace?(sql_item)
          @sql_traces.any? do |(_, existing_trace)|
            existing_trace.max_call_time < sql_item.duration
          end
        end

        # this should always be called under the @samples_lock
        def remove_shortest_trace
          shortest_key, _ = @sql_traces.min_by { |(_, trace)| trace.max_call_time }
          @sql_traces.delete(shortest_key)
        end


        def harvest!
          return [] unless enabled?

          slowest = []
          @samples_lock.synchronize do
            slowest = @sql_traces.values
            @sql_traces = {}
          end
          slowest.each {|trace| trace.prepare_to_send }
          slowest
        end

        def reset!
          @samples_lock.synchronize do
            @sql_traces = {}
          end
        end

        def merge!
          @samples_lock.synchronize do
            sql_traces.each do |trace|
              existing_trace = @sql_traces[trace.sql]
              if existing_trace
                existing_trace.aggregate_trace(trace)
              else
                @sql_traces[trace.sql] = trace
              end
            end
          end
        end


      end

      class TransactionSqlData
        attr_reader :action_metric_name
        attr_reader :uri
        attr_reader :sql_data

        def initialize
          @sql_data = []
        end

        def set_transaction_info(uri)
          @uri = uri
        end

        def set_transaction_name(name)
          @action_metric_name = name
        end
      end

      class SlowSql
        attr_reader :statement
        attr_reader :metric_name
        attr_reader :duration
        attr_reader :backtrace
        attr_reader :start_time

        def initialize(statement, metric_name, duration, t0,  backtrace=nil)
          @start_time = t0
          @statement = statement
          @metric_name = metric_name
          @duration = duration
          @backtrace = backtrace
        end

        def sql
          statement.sql
        end

        def obfuscate
          TingYun::Agent::Database.obfuscate_sql(statement)
        end


        def normalize
          TingYun::Agent::Database::Obfuscator.instance.default_sql_obfuscator(statement)
        end

        def explain
          if statement.config && statement.explainer
            TingYun::Agent::Database.explain_sql(statement.sql, statement.config, statement.explainer)
          end
        end

        # We can't serialize the explainer, so clear it before we transmit
        def prepare_to_send
          statement.explainer = nil
        end
      end



      class SqlTrace < TingYun::Metrics::Stats

        attr_reader :action_metric_name
        attr_reader :uri
        attr_reader :sql
        attr_reader :slow_sql
        attr_reader :params

        def initialize(normalized_query, slow_sql, action_name, uri)
          super()
          @params = {}

          @action_metric_name = action_name
          @slow_sql = slow_sql
          @sql = normalized_query
          @uri = uri
          @params[:stacktrace] = slow_sql.backtrace if slow_sql.backtrace
          record_data_point(float(slow_sql.duration))
        end

        def aggregate(slow_sql, action_name, uri)
          if slow_sql.duration > max_call_time
            @action_metric_name = action_name
            @slow_sql = slow_sql
            @uri = uri
            @params[:stacktrace] = slow_sql.backtrace if slow_sql.backtrace
          end
          record_data_point(float(slow_sql.duration))
        end

        def aggregate_trace(trace)
          aggregate(trace.slow_sql, trace.path, trace.url)
        end

        def prepare_to_send
          @sql = @slow_sql.sql unless need_to_obfuscate?
          @params[:explainPlan] = @slow_sql.explain if need_to_explain?
        end

        def need_to_obfuscate?
          Agent.config[:'nbs.action_tracer.record_sql'].to_s == 'obfuscated'
        end

        def need_to_explain?
          Agent.config[:'nbs.action_tracer.explain_enabled']
        end


        include TingYun::Support::Coerce

        def to_collector_array(encoder)
          [
              @slow_sql.start_time,
              string(@action_metric_name),
              string(@slow_sql.metric_name),
              string(@uri),
              string(@sql),
              int(@call_count),
              TingYun::Helper.time_to_millis(@total_call_time),
              TingYun::Helper.time_to_millis(@max_call_time),
              TingYun::Helper.time_to_millis(@min_call_time),
              encoder.encode(@params)
          ]
        end
      end
    end
  end
end
