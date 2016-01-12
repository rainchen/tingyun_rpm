# encoding: utf-8




require 'ting_yun/instrumentation/support/evented_subscriber'
require 'ting_yun/constants'

module TingYun
  module Instrumentation
    class ActionViewSubscriber < TingYun::Instrumentation::Support::EventedSubscriber


      def start(name, id, payload)#THREAD_LOCAL_ACCESS
        event = RenderEvent.new(name, Time.now, nil, id, payload)
        push_event(event)

      rescue => e
        log_notification_error(e, name, 'start')
      end

      def finish(name, id, payload) #THREAD_LOCAL_ACCESS
        event = pop_event(id)
        record_metrics(event)
      rescue => e
        log_notification_error(e, name, 'finish')
      end

      def record_metrics(event)

        exclusive = event.duration * 1000
        TingYun::Agent.agent.stats_engine.record_scoped_and_unscoped_metrics(event.metric_name, nil, event.duration*1000, exclusive)

      end


      def log_notification_error(error, name, event_type)
        # These are important enough failures that we want the backtraces
        # logged at error level, hence the explicit log_exception call.
        TingYun::Agent.logger.error("Error during #{event_type} callback for event '#{name}':")
        TingYun::Agent.logger.log_exception(:error, error)
      end


      class RenderEvent < TingYun::Instrumentation::Support::Event
        def recordable?
          name[0] == '!' ||
              metric_name == 'View/text template/Rendering' ||
              metric_name == "View/#{TingYun::Constants::UNKNOWN_METRIC}/Partial"
        end

        def metric_name
          if parent && (payload[:virtual_path] ||
              (parent.payload[:identifier] =~ /template$/))
            return parent.metric_name
          elsif payload.key?(:virtual_path)
            identifier = payload[:virtual_path]
          else
            identifier = payload[:identifier]
          end

          # memoize
          @metric_name ||= "View/#{metric_path(identifier)}/#{metric_action(name)}"
        end

        def metric_path(identifier)
          if identifier == nil
            'file'
          elsif identifier =~ /template$/
            identifier
          elsif (parts = identifier.split('/')).size > 1
            parts[-2..-1].join('/')
          else
            TingYun::Constants::UNKNOWN_METRIC
          end
        end

        def metric_action(name)
          case name
            when /render_template.action_view$/  then 'Rendering'
            when 'render_partial.action_view'    then 'Partial'
            when 'render_collection.action_view' then 'Partial'
          end
        end
      end
    end

  end
end

TingYun::Support::LibraryDetection.defer do
  @name = :rails4_view

  depends_on do
    defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 4
  end

  depends_on do
    !TingYun::Agent.config[:disable_view_instrumentation] &&
        !TingYun::Instrumentation::ActionViewSubscriber.subscribed?
  end

  executes do
    TingYun::Agent.logger.info 'Installing Rails 4 view instrumentation'
  end

  executes do
    TingYun::Instrumentation::ActionViewSubscriber.subscribe(/render_.+\.action_view$/)
  end
end

