# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/transaction_namer'
require 'ting_yun/agent/transaction'
require 'ting_yun/agent'

module TingYun
  module Instrumentation
    module Support
      module ControllerInstrumentation

        NR_DEFAULT_OPTIONS    = {}.freeze          unless defined?(NR_DEFAULT_OPTIONS   )

        def perform_action_with_tingyun_trace (*args, &block)

          state = TingYun::Agent::TransactionState.tl_get

          state.request = self.request
          trace_options = args.last.is_a?(Hash) ? args.last : NR_DEFAULT_OPTIONS
          category = trace_options[:category] || :controller
          txn_options = create_transaction_options(trace_options)

          begin
             txn = TingYun::Agent::Transaction.start(state, category, txn_options)
            begin
              yield
            rescue => e
              ::TingYun::Agent.notice_error(e)
              raise
            end
          ensure
            Transaction.stop(state)
          end
        end

        protected

        def create_transaction_options(trace_options)
          txn_options = {}

          txn_options[:request] ||= request if respond_to?(:request)
          txn_options[:filtered_params] = trace_options[:params]
          txn_options[:transaction_name] = TingYun::Instrumentation::Support::TransactionNamer.name_for(nil, self, category, trace_options)
          txn_options[:apdex_start_time] = Time.now

          txn_options
        end
      end
    end
  end

end
