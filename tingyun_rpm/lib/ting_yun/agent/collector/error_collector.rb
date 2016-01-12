# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/transaction/transaction_state'

module TingYun
  module Agent
    module Collector
      class ErrorCollector
        ERRORS_ACTION = "Errors/Count/".freeze
        ERRORS_ALL = "Errors/Count/All".freeze
        ERRORS_ALL_WEB = "Errors/Count/AllWeb".freeze
        ERRORS_ALL_BACK_GROUND = "Errors/Count/AllBackground".freeze


        #tag the exception,avoid the same exception record  multiple times in the middlwars and other point
        module Tag

          EXCEPTION_TAG_IVAR = :'@__ty_seen_exception' unless defined? EXCEPTION_TAG_IVAR

          def tag_exception(exception)
            begin
              exception.instance_variable_set(EXCEPTION_TAG_IVAR, true)
            rescue => e
              TingYun::Agent.logger.warn("Failed to tag exception: #{exception}: ", e)
            end
          end

          def exception_tagged?(exception)
            exception.instance_variable_defined?(EXCEPTION_TAG_IVAR)
          end

        end
        include Tag

        module Metric
          def aggregated_metric_names(txn)
            metric_names = [ERRORS_ALL]
            return metric_names unless txn

            if txn.recording_web_transaction?
              metric_names << ERRORS_ALL_WEB
            else
              metric_names << ERRORS_ALL_BACK_GROUND
            end

            metric_names
          end

          def action_metric_name(txn,options)
            "#{ERRORS_ACTION}#{txn.best_name}" if txn
          end

        end
        include Metric


        def initialize

        end


        def notice_error(exception, options={})
          tag_exception(exception)
          state = ::TingYun::Agent::TransactionState.tl_get
          increment_error_count!(state, exception, options)
        rescue => e
          ::TingYun::Agent.logger.warn("Failure when capturing error '#{exception}':", e)
          nil
        end

        # Increments a statistic that tracks total error rate
        def increment_error_count!(state, exception, options={})
          txn = state.current_transaction

          metric_names = aggregated_metric_names(txn)

          action_metric = action_metric_name(txn, options)
          metric_names << action_metric if action_metric

          stats_engine = TingYun::Agent.agent.stats_engine
          stats_engine.record_unscoped_metrics(state, metric_names) do |stats|
            stats.increment_count
          end
        end

        def skip_notice_error?(exception)
          exception_tagged?(exception)
        end
      end
    end
  end
end
