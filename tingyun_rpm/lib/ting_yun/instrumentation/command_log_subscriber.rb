# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/datastore/metric_helper'


module TingYun
  module Instrumentation
    class CommandLogSubscriber

      MONGODB = 'MongoDB'.freeze

      def started(event)
        begin
          operations[event.operation_id] = event
        rescue Exception => e
          log_notification_error('started', e)
        end
      end


      def completed(event)
        begin
          state = TingYun::Agent::TransactionState.tl_get

          started_event = operations.delete(event.operation_id)

          base, *other_metrics = metrics(started_event)

          TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
              base, other_metrics, event.duration
          )
        rescue Exception => e
          log_notification_error('completed', e)
        end
      end

      alias :succeeded :completed
      alias :failed :completed




      private

      def log_notification_error(event_type, error)
        TingYun::Agent.logger.error("Error during MongoDB #{event_type} event:")
        TingYun::Agent.logger.log_exception(:error, error)
      end


      def operations
        @operations ||= {}
      end

      def metrics(event)
        TingYun::Agent::Datastore::MetricHelper.metrics_for(MONGODB, event.command_name, collection(event))
      end

    end
  end
end
