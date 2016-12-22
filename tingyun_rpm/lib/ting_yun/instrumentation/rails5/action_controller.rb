# encoding: utf-8


TingYun::Support::LibraryDetection.defer do
  named :rails5_controller

  depends_on do
    defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 5
  end

  depends_on do
    defined?(ActionController) && defined?(ActionController::Base)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Rails 5 Controller instrumentation'
  end

  executes do
    class ActionController::Base
      include TingYun::Instrumentation::Support::ControllerInstrumentation
    end
    ::TingYun::Instrumentation::Rails::ActionControllerSubscriber \
      .subscribe(/^process_action.action_controller$/)
  end
end
