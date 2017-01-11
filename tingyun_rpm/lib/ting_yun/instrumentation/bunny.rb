TingYun::Support::LibraryDetection.defer do
  named :bunny

  depends_on do
    defined?(::Bunny::VERSION) && !TingYun::Agent.config[:disable_rabbitmq]
  end


  executes do
    TingYun::Agent.logger.info 'Installing bunny(for rabbitmq) Instrumentation'
  end

  executes do
    ::Bunny::Session.class_eval do

    end
  end

end