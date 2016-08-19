# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/support/helper'
require 'ting_yun/agent/method_tracer_helpers'
require 'ting_yun/agent/transaction/transaction_metrics'
require 'ting_yun/agent/transaction/request_attributes'
require 'ting_yun/agent/transaction/attributes'
require 'ting_yun/agent/transaction/exceptions'
require 'ting_yun/agent/transaction/apdex'


module TingYun
  module Agent
    # web transaction
    class Transaction


      APDEX_TXN_METRIC_PREFIX = 'Apdex/'.freeze
      SUBTRANSACTION_PREFIX = 'Nested/'.freeze
      CONTROLLER_PREFIX = 'WebAction/'.freeze
      RAKE_TRANSACTION_PREFIX     = 'BackgroundAction/Rake'.freeze
      TASK_PREFIX = 'OtherTransaction/Background/'.freeze
      RACK_PREFIX = 'Rack/'.freeze
      SINATRA_PREFIX = 'Sinatra/'.freeze
      MIDDLEWARE_PREFIX = 'Middleware/Rack/'.freeze
      GRAPE_PREFIX = 'Grape/'.freeze
      RAKE_PREFIX = 'Rake'.freeze
      WEB_TRANSACTION_CATEGORIES = [:controller, :uri, :rack, :sinatra, :grape, :middleware, :thrift].freeze
      EMPTY_SUMMARY_METRICS = [].freeze
      MIDDLEWARE_SUMMARY_METRICS = ['Middleware/all'.freeze].freeze

      TRACE_OPTIONS_SCOPED = {:metric => true, :scoped_metric => true}.freeze
      TRACE_OPTIONS_UNSCOPED = {:metric => true, :scoped_metric => false}.freeze
      NESTED_TRACE_STOP_OPTIONS = {:metric => true}.freeze


      # A Time instance for the start time, never nil
      attr_accessor :start_time


      # A Time instance used for calculating the apdex score, which
      # might end up being @start, or it might be further upstream if
      # we can find a request header for the queue entry time
      attr_accessor :apdex,
                    :category,
                    :frame_stack,
                    :default_name,
                    :exceptions,
                    :metrics,
                    :guid,
                    :attributes,
                    :request_attributes


      def initialize(category, options)
        @guid = options[:client_transaction_id] || generate_guid
        @exceptions = TingYun::Agent::Transaction::Exceptions.new
        @metrics = TingYun::Agent::TransactionMetrics.new
        @attributes = TingYun::Agent::Transaction::Attributes.new
        @apdex = TingYun::Agent::Transaction::Apdex.new(options[:apdex_start_time] || @start_time)

        @has_children = false
        @category = category

        @start_time = Time.now

        @frame_stack = []
        @frozen_name = nil
        @default_name = TingYun::Helper.correctly_encoded(options[:transaction_name])






        if request = options[:request]
          @request_attributes = TingYun::Agent::Transaction::RequestAttributes.new request
        else
          @request_attributes = nil
        end
      end


      def request_path
        @request_attributes && @request_attributes.request_path
      end

      def request_port
        @request_attributes && @request_attributes.port
      end

      def self.wrap(state, name, category, options = {})
        Transaction.start(state, category, options.merge(:transaction_name => name))

        begin
          # We shouldn't raise from Transaction.start, but only wrap the yield
          # to be absolutely sure we don't report agent problems as app errors
          yield
        rescue => e
          Transaction.notice_error(e)
          raise e
        ensure
          Transaction.stop(state)
        end
      end


      def self.start(state, category, options)
        category ||= :controller
        txn = state.current_transaction
        options[:client_transaction_id] = state.client_transaction_id
        if txn
          txn.create_nested_frame(state, category, options)
        else
          txn = start_new_transaction(state, category, options)
        end

        # merge params every step into here
        txn.attributes.merge_request_parameters(options[:filtered_params])

        txn
      rescue => e
        TingYun::Agent.logger.error("Exception during Transaction.start", e)
      end

      def self.start_new_transaction(state, category, options)
        txn = Transaction.new(category, options)
        state.reset(txn)
        txn.start(state)
        txn
      end

      def start(state)
        return if !state.execution_traced?

        ::TingYun::Agent::Collector::TransactionSampler.on_start_transaction(state, start_time)
        ::TingYun::Agent::Collector::SqlSampler.on_start_transaction(state, request_path)
        ::TingYun::Agent.instance.events.notify(:start_transaction)

        frame_stack.push TingYun::Agent::MethodTracerHelpers.trace_execution_scoped_header(state, Time.now.to_f)
        name_last_frame @default_name
        freeze_name_and_execute if @default_name.start_with?(RAKE_TRANSACTION_PREFIX)
      end

      def create_nested_frame(state, category, options)
        @has_children = true
        frame_stack.push TingYun::Agent::MethodTracerHelpers.trace_execution_scoped_header(state, Time.now.to_f)
        name_last_frame(options[:transaction_name])

        set_default_transaction_name(options[:transaction_name], category)
      end


      def set_default_transaction_name(name, category)
        return log_frozen_name(name) if name_frozen?
        if influences_transaction_name?(category)
          self.default_name = name
          @category = category if category
        end
      end


      def self.stop(state, end_time = Time.now)

        txn = state.current_transaction

        unless txn
          TingYun::Agent.logger.error("Failed during Transaction.stop because there is no current transaction")
          return
        end

        nested_frame = txn.frame_stack.pop

        if txn.frame_stack.empty?
          txn.stop(state, end_time, nested_frame)
          state.reset
        else
          nested_name = nested_transaction_name(nested_frame.name)

          if nested_name.start_with?(MIDDLEWARE_PREFIX)
            summary_metrics = MIDDLEWARE_SUMMARY_METRICS
          else
            summary_metrics = EMPTY_SUMMARY_METRICS
          end

          TingYun::Agent::MethodTracerHelpers.trace_execution_scoped_footer(
              state,
              nested_frame.start_time.to_f,
              nested_name,
              summary_metrics,
              nested_frame,
              NESTED_TRACE_STOP_OPTIONS,
              end_time.to_f)

        end

        :transaction_stopped
      rescue => e
        state.reset
        TingYun::Agent.logger.error("Exception during Transaction.stop", e)
        nil
      end


      def stop(state, end_time, outermost_frame)

        freeze_name_and_execute

        if @has_children
          name = Transaction.nested_transaction_name(outermost_frame.name)
          trace_options = TRACE_OPTIONS_SCOPED
        else
          name = @frozen_name
          trace_options = TRACE_OPTIONS_UNSCOPED
        end

        if needs_middleware_summary_metrics?(name)
          summary_metrics_with_exclusive_time = MIDDLEWARE_SUMMARY_METRICS
        else
          summary_metrics_with_exclusive_time = EMPTY_SUMMARY_METRICS
        end


        TingYun::Agent::MethodTracerHelpers.trace_execution_scoped_footer(
            state,
            start_time.to_f,
            name,
            summary_metrics_with_exclusive_time,
            outermost_frame,
            trace_options,
            end_time.to_f)

        commit(state, end_time, name) unless ignore(best_name)
      end

      def self.nested_transaction_name(name)
        if name.start_with?(CONTROLLER_PREFIX) || name.start_with?(RAKE_TRANSACTION_PREFIX)
          "#{SUBTRANSACTION_PREFIX}#{name}"
        else
          name
        end
      end

      def commit(state, end_time, outermost_node_name)

        assign_agent_attributes


        transaction_sampler.on_finishing_transaction(state, self, end_time)

        sql_sampler.on_finishing_transaction(state, @frozen_name)

        record_summary_metrics(outermost_node_name, end_time)
        record_apdex(end_time)
        @exceptions.record_exceptions(request_path, request_port, best_name, @attributes)


        merge_metrics
      end


      def record_summary_metrics(outermost_node_name,end_time)
        unless @frozen_name == outermost_node_name
          @metrics.record_unscoped(@frozen_name, TingYun::Helper.time_to_millis(end_time.to_f - start_time.to_f))
        end
      end

      def assign_agent_attributes

        @attributes.add_agent_attribute(:threadName,  "pid-#{$$}");

        if @request_attributes
          @request_attributes.assign_agent_attributes @attributes
        end

      end



      def record_apdex(end_time=Time.now)
        total_duration = (end_time - apdex_start)*1000
        if recording_web_transaction?
          record_apdex_metrics(APDEX_TXN_METRIC_PREFIX, total_duration, apdex_t)
        end
      end


      def record_apdex_metrics(transaction_prefix, total_duration, current_apdex_t)
        return unless current_apdex_t
        return unless @frozen_name.start_with?(CONTROLLER_PREFIX)

        apdex_bucket_global = apdex_bucket(total_duration, current_apdex_t)
        txn_apdex_metric = @frozen_name.sub(/^[^\/]+\//, transaction_prefix)
        @metrics.record_unscoped(txn_apdex_metric, apdex_bucket_global, current_apdex_t)
      end


      def apdex_bucket(duration, current_apdex_t)
        self.class.apdex_bucket(duration, @exceptions.had_error?, current_apdex_t)
      end

      def self.apdex_bucket(duration, failed, apdex_t)
        case
          when failed
            :apdex_f
          when duration <= apdex_t
            :apdex_s
          when duration <= 4 * apdex_t
            :apdex_t
          else
            :apdex_f
        end
      end

      def apdex_t
        TingYun::Agent.config[:apdex_t]
      end



      # This transaction-local hash may be used as temprory storage by
      # instrumentation that needs to pass data from one instrumentation point
      # to another.
      #
      # For example, if both A and B are instrumented, and A calls B
      # but some piece of state needed by the instrumentation at B is only
      # available at A, the instrumentation at A may write into the hash, call
      # through, and then remove the key afterwards, allowing the
      # instrumentation at B to read the value in between.
      #
      # Keys should be symbols, and care should be taken to not generate key
      # names dynamically, and to ensure that keys are removed upon return from
      # the method that creates them.
      #
      def instrumentation_state
        @instrumentation_state ||= {}
      end

      def with_database_metric_name(model, method, product=nil)
        previous = self.instrumentation_state[:datastore_override]
        model_name = case model
                       when Class
                         model.name
                       when String
                         model
                       else
                         model.to_s
                     end
        self.instrumentation_state[:datastore_override] = [method, model_name, product]
        yield
      ensure
        self.instrumentation_state[:datastore_override] = previous
      end

      def freeze_name_and_execute
        if !name_frozen?
          @name_frozen = true
          @frozen_name = best_name
        end

        yield if block_given?
      end

      def promoted_transaction_name(name)
        if name.start_with?(MIDDLEWARE_PREFIX)
          "#{CONTROLLER_PREFIX}#{name}"
        else
          name
        end
      end

      def merge_metrics
        TingYun::Agent.instance.stats_engine.merge_transaction_metrics!(@metrics, best_name)
      end

      def name_last_frame(name)
        frame_stack.last.name = name
      end

      def name_frozen?
        @frozen_name ? true : false
      end

      def log_frozen_name(name)
        TingYun::Agent.logger.warn("Attempted to rename transaction to '#{name}' after transaction name was already frozen as '#{@frozen_name}'.")
        nil
      end

      def influences_transaction_name?(category)
        !category || frame_stack.size == 1 || similar_category?(category)
      end

      def web_category?(category)
        WEB_TRANSACTION_CATEGORIES.include?(category)
      end

      def similar_category?(category)
        web_category?(@category) == web_category?(category)
      end

      def recording_web_transaction?
        web_category?(@category)
      end

      def self.recording_web_transaction? #THREAD_LOCAL_ACCESS
        txn = tl_current
        txn && txn.recording_web_transaction?
      end

      def self.tl_current
        TingYun::Agent::TransactionState.tl_get.current_transaction
      end

      def needs_middleware_summary_metrics?(name)
        name.start_with?(MIDDLEWARE_PREFIX)
      end

      alias_method :ignore, :needs_middleware_summary_metrics?

      def best_name
        @frozen_name || @default_name || ::TingYun::Agent::UNKNOWN_METRIC
      end

      def queue_time
        @apdex_start ? @start_time - @apdex_start : 0
      end


      def agent
        TingYun::Agent.instance
      end

      def sql_sampler
        agent.sql_sampler
      end


      def transaction_sampler
        TingYun::Agent.instance.transaction_sampler
      end

      # See TingYun::Agent.notice_error for options and commentary
      def self.notice_error(e, options={})
        state = TingYun::Agent::TransactionState.tl_get
        txn = state.current_transaction
        if txn
          txn.exceptions.notice_error(e, options)
        elsif TingYun::Agent.instance
          TingYun::Agent.instance.error_collector.notice_error(e, options)
        end
      end

      HEX_DIGITS = (0..15).map{|i| i.to_s(16)}
      GUID_LENGTH = 16

      # generate a random 64 bit uuid
      private
      def generate_guid
        guid = ''
        GUID_LENGTH.times do
          guid << HEX_DIGITS[rand(16)]
        end
        guid
      end

    end
  end
end
