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
        @start_time = Time.now

        @exceptions = TingYun::Agent::Transaction::Exceptions.new
        @metrics = TingYun::Agent::TransactionMetrics.new
        @attributes = TingYun::Agent::Transaction::Attributes.new
        @apdex = TingYun::Agent::Transaction::Apdex.new(options[:apdex_start_time] || @start_time)

        @has_children = false
        @category = category

        @guid = options[:client_transaction_id] || generate_guid
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
        if @frozen_name
          TingYun::Agent.logger.warn("Attempted to rename transaction to '#{name}' after transaction name was already frozen as '#{@frozen_name}'.")
          return
        end
        if influences_transaction_name?(category)
          self.default_name = name
          @category = category if category
        end
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


      def commit(state, end_time, outermost_node_name)

        assign_agent_attributes


        transaction_sampler.on_finishing_transaction(state, self, end_time)

        sql_sampler.on_finishing_transaction(state, @frozen_name)

        record_summary_metrics(outermost_node_name, end_time)
        @apdex.record_apdex(@frozen_name, end_time,@exceptions.had_error?)
        @exceptions.record_exceptions(request_path, request_port, best_name, @attributes)


        TingYun::Agent.instance.stats_engine.merge_transaction_metrics!(@metrics, best_name)
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
        unless @frozen_name
          @frozen_name = best_name
        end

        yield if block_given?
      end


      def name_last_frame(name)
        frame_stack.last.name = name
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

      def self.nested_transaction_name(name)
        if name.start_with?(CONTROLLER_PREFIX) || name.start_with?(RAKE_TRANSACTION_PREFIX)
          "#{SUBTRANSACTION_PREFIX}#{name}"
        else
          name
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

      def self.recording_web_transaction? #THREAD_LOCAL_ACCESS
        txn = tl_current
        txn && txn.web_category?(@category)
      end

      def self.tl_current
        TingYun::Agent::TransactionState.tl_get.current_transaction
      end

      def self.metrics
        txn = tl_current
        txn && txn.metrics
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
