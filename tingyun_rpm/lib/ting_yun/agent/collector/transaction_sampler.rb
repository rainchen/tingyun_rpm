# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_sample_builder'
require 'ting_yun/agent/collector/transaction_sampler/slowest_sample_buffer'

require 'ting_yun/agent/transaction/transaction_state'


module TingYun
  module Agent
    module Collector
      class TransactionSampler

        attr_accessor :last_sample


        def initialize
          @lock = Mutex.new
          @sample_buffers = []
          @sample_buffers << TingYun::Agent::Collector::TransactionSampler::SlowestSampleBuffer.new
        end


        def notice_push_frame(state, time=Time.now)
          builder = state.transaction_sample_builder
          return unless builder
          builder.trace_entry(time.to_f)
        end

        # Informs the transaction sample builder about the end of a traced frame
        def notice_pop_frame(state, frame, time = Time.now)
          builder = state.transaction_sample_builder
          return unless builder
          builder.trace_exit(frame, time.to_f)
        end


        def self.on_start_transaction(state, time)
          if TingYun::Agent.config[:'nbs.action_tracer.enabled']
            state.transaction_sample_builder ||= TingYun::Agent::TransactionSampleBuilder.new(time)
          else
            state.transaction_sample_builder = nil
          end
        end

        def on_finishing_transaction(state, txn, time=Time.now.to_f)
          last_builder = state.transaction_sample_builder
          return unless last_builder && TingYun::Agent.config[:'nbs.action_tracer.enabled']

          last_builder.finish_trace(time)

          state.transaction_sample_builder = nil


          final_trace = last_builder.trace
          final_trace.metric_name = txn.best_name
          final_trace.uri = txn.request_path
          final_trace.attributes = txn.attributes


          @lock.synchronize do
            @last_sample = final_trace

            store_sample(@last_sample)
            @last_sample
          end
        end

        def store_sample(sample)
          @sample_buffers.each do |sample_buffer|
            sample_buffer.store(sample)
          end
        end


        # Attaches an SQL query on the current transaction trace node.
        # @param sql [String] the SQL query being recorded
        # @param config [Object] the driver configuration for the connection
        # @param duration [Float] number of seconds the query took to execute
        # @param explainer [Proc] for internal use only - 3rd-party clients must
        #                         not pass this parameter.
        # duration{:type => sec}
        def notice_sql(sql, config, duration, state=nil, explainer=nil, binds=[], name="SQL")
          # some statements (particularly INSERTS with large BLOBS
          # may be very large; we should trim them to a maximum usable length
          state ||= TingYun::Agent::TransactionState.tl_get
          builder = state.transaction_sample_builder
          if state.sql_recorded?
            statement = TingYun::Agent::Database::Statement.new(sql, config, explainer, binds, name)
            action_tracer_segment(builder, statement, duration, :sql)
          end
        end

        # duration{:type => sec}
        def notice_nosql(key, duration) #THREAD_LOCAL_ACCESS
          builder = tl_builder
          return unless builder
          action_tracer_segment(builder, key, duration, :key)
        end

        # duration{:type => sec}
        def notice_nosql_statement(statement, duration) #THREAD_LOCAL_ACCESS
          builder = tl_builder
          return unless builder
          action_tracer_segment(builder, statement, duration, :statement)
        end



        MAX_DATA_LENGTH = 16384
        # This method is used to record metadata into the currently
        # active node like a sql query, memcache key, or Net::HTTP uri
        #
        # duration is milliseconds, float value.
        # duration{:type => sec}
        def action_tracer_segment(builder, message, duration, key)
          return unless builder
          node = builder.current_node
          if node
            if key == :sql
              statement = node[:sql]
              if statement && !statement.sql.empty?
                statement.sql = self.class.truncate_message(statement.sql + "\n#{message.sql}") if statement.sql.length <= MAX_DATA_LENGTH
              else
                # message is expected to have been pre-truncated by notice_sql
                node[:sql] =  message
              end
            else
              node[key] = self.class.truncate_message(message)
            end
            append_backtrace(node, duration)
          end
        end

        # Truncates the message to `MAX_DATA_LENGTH` if needed, and
        # appends an ellipsis because it makes the trucation clearer in
        # the UI
        def self.truncate_message(message)
          if message.length > (MAX_DATA_LENGTH - 4)
            message.slice!(MAX_DATA_LENGTH - 4..message.length)
            message << '...'
          else
            message
          end
        end

        # Appends a backtrace to a node if that node took longer
        # than the specified duration
        def append_backtrace(node, duration)
          if duration*1000 >= Agent.config[:'nbs.action_tracer.stack_trace_threshold']
            trace =  caller.reject! { |t| t.include?('tingyun_rpm') }
            trace = trace.first(40) if trace.length > 40
            node[:stacktrace] = trace
          end

        end

        def harvest!
          return [] unless TingYun::Agent.config[:'nbs.action_tracer.enabled']

          samples = @lock.synchronize do
            @last_sample = nil
            harvest_from_sample_buffers
          end

          prepare_samples(samples)
        end

        def harvest_from_sample_buffers
          result = []
          @sample_buffers.each { |buffer| result.concat(buffer.harvest_samples) }
          result.uniq
        end

        def prepare_samples(samples)
          samples.select do |sample|
            begin
              sample.prepare_to_send!
            rescue => e

              TingYun::Agent.logger.error('Failed to prepare transaction trace. Error: ', e)

              false
            else
              true
            end
          end
        end

        def merge!(previous)
          @lock.synchronize do
            @sample_buffers.each do |buffer|
              buffer.store_previous(previous)
            end
          end
        end

        def reset!
          @lock.synchronize do
            @sample_buffers.each { |sample| sample.reset! }
          end
        end


        def add_node_info(params)
          builder = tl_builder
          return unless builder
          params.each { |k,v| builder.current_node.instance_variable_set(('@'<<k.to_s).to_sym, v)  }
        end

        def tl_builder
          TingYun::Agent::TransactionState.tl_get.transaction_sample_builder
        end

      end
    end
  end
end
