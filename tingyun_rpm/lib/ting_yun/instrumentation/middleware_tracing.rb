# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'rack/request'
require 'ting_yun/instrumentation/support/queue_time'
require 'ting_yun/agent/transaction'
require 'ting_yun/agent'
require 'ting_yun/instrumentation/support/external_error'

module TingYun
  module Instrumentation
    module MiddlewareTracing
      TXN_STARTED_KEY = 'tingyun.transaction_started'.freeze unless defined?(TXN_STARTED_KEY)

      def _nr_has_middleware_tracing
        true
      end

      def build_transaction_options(env, first_middleware)
        opts = transaction_options
        opts = merge_first_middleware_options(opts, env) if first_middleware
        opts
      end

      def merge_first_middleware_options(opts, env)
        opts.merge(
            :request          => ::Rack::Request.new(env),
            :apdex_start_time => TingYun::Instrumentation::Support::QueueTime.parse_frontend_timestamp(env)
        )
      end

      def capture_http_response_code(state, result)
        if result.is_a?(Array) && state.current_transaction
          state.current_transaction.add_agent_attribute(:httpStatus, result[0].to_s)
        end
      end
      # the trailing unless is for the benefit for Ruby 1.8.7 and can be removed
      # when it is deprecated.
      CONTENT_TYPE = 'Content-Type'.freeze unless defined?(CONTENT_TYPE)

      def capture_response_content_type(state, result)
        if result.is_a?(Array) && state.current_transaction
          _, headers, _ = result
          state.current_transaction.add_agent_attribute(:contentType, headers[CONTENT_TYPE].to_s)
        end
      end

      def capture_request(state, env)
        if env.is_a? Hash

        end
      end

      def call(env)
        first_middleware = note_transaction_started(env)

        state = TingYun::Agent::TransactionState.tl_get
        if first_middleware
          capture_request(state, env)
        end
        begin
          TingYun::Agent::Transaction.start(state, category, build_transaction_options(env, first_middleware))
          events.notify(:before_call, env) if first_middleware

          result = target.call(env)

          if first_middleware
            capture_http_response_code(state, result)
            capture_response_content_type(state, result)
            events.notify(:after_call, result)
          end

          result
        rescue Exception => e

          TingYun::Agent.notice_error(e)
          raise e
        ensure
          TingYun::Agent::Transaction.stop(state)
        end
      end


      def note_transaction_started(env)
        env[TXN_STARTED_KEY] = true unless env[TXN_STARTED_KEY]
      end

      def events
        ::TingYun::Agent.instance.events
      end
    end
  end
end
