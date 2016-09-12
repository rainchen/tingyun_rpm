# encoding: utf-8
require 'ting_yun/instrumentation/support/evented_subscriber'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/active_record_helper'
require 'ting_yun/support/helper'
require 'ting_yun/agent/collector/transaction_sampler'
require 'ting_yun/agent/collector/sql_sampler'
require 'ting_yun/agent/database'

module TingYun
  module Instrumentation
    module Rails4
      class ActiveRecordSubscriber < TingYun::Instrumentation::Support::EventedSubscriber
        CACHED_QUERY_NAME = 'CACHE'.freeze unless defined? CACHED_QUERY_NAME

        def initialize
          # We cache this in an instance variable to avoid re-calling method
          # on each query.
          @explainer = method(:explain_plan)
          super
        end

        def explain_plan(statement)
          TingYun::Agent::Database.explain_plan(statement)
        end

        def start(name, id, payload) #THREAD_LOCAL_ACCESS

          return if payload[:name] == CACHED_QUERY_NAME
          super
        rescue => e
          log_notification_error(e, name, 'start')
        end

        def finish(name, id, payload) #THREAD_LOCAL_ACCESS
          return if payload[:name] == CACHED_QUERY_NAME
          state = TingYun::Agent::TransactionState.tl_get
          event = pop_event(id)
          config = active_record_config_for_event(event)
          base_metric = record_metrics(event, config)
          notice_sql(state, event, config, base_metric)
        rescue Exception => e
          log_notification_error(e, name, 'finish')
        end


        def notice_sql(state, event, config, metric)
          stack  = state.traced_method_stack
          state.timings.sql_duration = (state.timings.sql_duration || 0) + event.duration
          # enter transaction trace node
          frame = stack.push_frame(state, :active_record, event.time)

          sql_sampler.notice_sql(event.payload[:sql], metric, config,
                        TingYun::Helper.milliseconds_to_seconds(event.duration),
                        state, @explainer, event.payload[:binds], event.payload[:name])

          transaction_sampler.notice_sql(event.payload[:sql], config, event.duration,
                        state, @explainer, event.payload[:binds], event.payload[:name])
          # exit transaction trace node
          stack.pop_frame(state, frame, metric, event.end)
        end

        def record_metrics(event, config)
          base, *other_metrics = TingYun::Instrumentation::Support::ActiveRecordHelper.metrics_for(event.payload[:name],
                                                                                                   TingYun::Helper.correctly_encoded(event.payload[:sql]),
                                                                                                   config && config[:adapter])

          TingYun::Agent.agent.stats_engine.tl_record_scoped_and_unscoped_metrics(base, other_metrics, event.duration)

          base
        end


        def active_record_config_for_event(event)
          return unless event.payload[:connection_id]

          connection = nil
          connection_id = event.payload[:connection_id]

          ::ActiveRecord::Base.connection_handler.connection_pool_list.each do |handler|
            connection = handler.connections.detect do |conn|
              conn.object_id == connection_id
            end

            break if connection
          end

          connection.instance_variable_get(:@config) if connection
        end

        def transaction_sampler
          ::TingYun::Agent::Collector::TransactionSampler
        end

        def sql_sampler
          ::TingYun::Agent::Collector::SqlSampler
        end
      end
    end
  end
end

TingYun::Support::LibraryDetection.defer do
  named :active_record_4


  depends_on do
    defined?(::ActiveRecord) && defined?(::ActiveRecord::Base) &&
        defined?(::ActiveRecord::VERSION) &&
        ::ActiveRecord::VERSION::MAJOR.to_i >= 4
  end

  depends_on do
    !TingYun::Instrumentation::Rails4::ActiveRecordSubscriber.subscribed?
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing ActiveRecord 4 instrumentation'
  end

  executes do
    ActiveSupport::Notifications.subscribe('sql.active_record',
                                           TingYun::Instrumentation::Rails4::ActiveRecordSubscriber.new)
    ::TingYun::Instrumentation::Support::ActiveRecordHelper.instrument_additional_methods
  end
end