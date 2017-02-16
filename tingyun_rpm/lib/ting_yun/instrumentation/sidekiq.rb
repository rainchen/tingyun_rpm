# encoding: utf-8



TingYun::Support::LibraryDetection.defer do
  named :sidekiq

  depends_on do
    defined?(::Sidekiq) && !TingYun::Agent.config[:disable_sidekiq]
  end


  executes do
    TingYun::Agent.logger.info 'Installing Sidekiq Instrumentation'
    require 'ting_yun/instrumentation/support/controller_instrumentation'
  end

  executes do
    class TingYun::SidekiqInstrumentation
      def call(worker_instance, msg, queue,*_)

      end
    end

    Sidekiq.configure_server do |config|
      config.server_middleware do |chain|
        chain.add TingYun::SidekiqInstrumentation
      end

      if config.respond_to?(:error_handlers)
        config.error_handlers << Proc.new do |error, *_|
          TingYun::Agent.notice_error(error)
        end
      end
    end
  end
end