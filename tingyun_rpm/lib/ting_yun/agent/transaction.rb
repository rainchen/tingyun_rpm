# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/support/helper'
require 'ting_yun/agent/method_tracer_helpers'
require 'ting_yun/agent/transaction/transaction_metrics'
require 'ting_yun/agent/transaction/request_attributes'
require 'ting_yun/agent/transaction/attributes'
require 'ting_yun/agent/transaction/exceptions'
require 'ting_yun/agent/transaction/apdex'
require 'ting_yun/agent/transaction/class_method'
require 'ting_yun/agent/transaction/instance_method'


module TingYun
  module Agent
    # web transaction
    class Transaction

      include TingYun::Agent::Transaction::InstanceMethod

      extend TingYun::Agent::Transaction::ClassMethod




      SUBTRANSACTION_PREFIX = 'Nested/'.freeze
      CONTROLLER_PREFIX = 'WebAction/'.freeze
      RAKE_TRANSACTION_PREFIX     = 'BackgroundAction/Rake'.freeze
      TASK_PREFIX = 'OtherTransaction/Background/'.freeze
      RACK_PREFIX = 'Rack/'.freeze
      SINATRA_PREFIX = 'Sinatra/'.freeze
      MIDDLEWARE_PREFIX = 'Middleware/Rack/'.freeze
      GRAPE_PREFIX = 'Grape/'.freeze
      RAKE_PREFIX = 'Rake'.freeze

      EMPTY_SUMMARY_METRICS = [].freeze
      MIDDLEWARE_SUMMARY_METRICS = ['Middleware/all'.freeze].freeze

      TRACE_OPTIONS_SCOPED = {:metric => true, :scoped_metric => true}.freeze
      TRACE_OPTIONS_UNSCOPED = {:metric => true, :scoped_metric => false}.freeze
      NESTED_TRACE_STOP_OPTIONS = {:metric => true}.freeze



      # A Time instance used for calculating the apdex score, which
      # might end up being @start, or it might be further upstream if
      # we can find a request header for the queue entry time


      attr_reader :apdex,
                  :exceptions,
                  :metrics,
                  :attributes,
                  :request_attributes,
                  :frame_stack,
                  :guid,
                  :category,
                  :default_name,
                  :start_time


      def initialize(category, options)
        @start_time = Time.now

        @exceptions = TingYun::Agent::Transaction::Exceptions.new
        @metrics = TingYun::Agent::TransactionMetrics.new
        @attributes = TingYun::Agent::Transaction::Attributes.new
        @apdex = TingYun::Agent::Transaction::Apdex.new(options[:apdex_start_time], @start_time)

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




      def stop(state, end_time, outermost_frame)

        freeze_name_and_execute

        if @has_children
          name = Transaction.nested_transaction_name(outermost_frame.name)
          trace_options = TRACE_OPTIONS_SCOPED
        else
          name = @frozen_name
          trace_options = TRACE_OPTIONS_UNSCOPED
        end

        if name.start_with?(MIDDLEWARE_PREFIX)
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

        commit(state, end_time, name)
      end


      def commit(state, end_time, outermost_node_name)

        assign_agent_attributes


        TingYun::Agent.instance.transaction_sampler.on_finishing_transaction(state, self, end_time)

        TingYun::Agent.instance.sql_sampler.on_finishing_transaction(state, @frozen_name)

        record_summary_metrics(outermost_node_name, end_time)
        @apdex.record_apdex(@frozen_name, end_time, @exceptions.had_error?)
        @exceptions.record_exceptions(request_path, request_port, best_name, @attributes)


        TingYun::Agent.instance.stats_engine.merge_transaction_metrics!(@metrics, best_name)
      end

    end
  end
end
