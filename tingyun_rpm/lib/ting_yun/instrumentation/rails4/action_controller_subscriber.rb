# encoding: utf-8

require 'ting_yun/instrumentation/support/evented_subscriber'
require 'ting_yun/instrumentation/support/queue_time'
require  'ting_yun/instrumentation/support/controller_instrumentation'

module TingYun
  module Instrumentation
    class ActionControllerSubscriber < TingYun::Instrumentation::Support::EventedSubscriber

      def start(name, id, payload)
        state = TransactionState.tl_get
        request = state.request
        event = ControllerEvent.new(name, Time.now, nil, id, payload, request)
        push_event(event)

      rescue => e
        log_notification_error(e, name, 'start')
      end

      def finish(name, id, payload)
        event = pop_event(id)
        event.payload.merge!(payload)

      rescue => e
        log_notification_error(e, name, 'finish')
      end



      class ControllerEvent < TingYun::Instrumentation::Support::Event

        attr_accessor :parent
        attr_reader :queue_start, :request

        def initialize(name, start, ending, transaction_id, payload, request)
          # We have a different initialize parameter list, so be explicit
          super(name, start, ending, transaction_id, payload)

          @request = request
          @controller_class = payload[:controller].split('::') \
            .inject(Object){|m,o| m.const_get(o)}

          if request && request.respond_to?(:env)
            @queue_start = QueueTime.parse_frontend_timestamp(request.env, self.time)
          end
        end

        def metric_name
          @metric_name ||= "Controller/#{metric_path}/#{metric_action}"
        end

        def metric_path
          @controller_class.controller_path
        end

        def metric_action
          payload[:action]
        end

        def to_s
          "#<TingYun::Instrumentation::ControllerEvent:#{object_id} name: \"#{name}\" id: #{transaction_id} payload: #{payload}}>"
        end
      end
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  @name = :rails4_controller

  depends_on do
    defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 4
  end

  depends_on do
    defined?(ActionController) && defined?(ActionController::Base)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Rails 4 Controller instrumentation'
  end

  executes do
    TingYun::Instrumentation::ActionControllerSubscriber \
      .subscribe(/^process_action.action_controller$/)
  end
end


