TingYun::Support::LibraryDetection.defer do
  named :bunny

  depends_on do
    defined?(::Bunny::VERSION) && !TingYun::Agent.config[:disable_rabbitmq]
  end


  executes do
    TingYun::Agent.logger.info 'Installing bunny(for rabbitmq) Instrumentation'
  end

  executes do
    ::Bunny::Exchange.class_eval do

      if public_method_defined? :publish


        def publish_with_tingyun(payload, opts = {})
          state = TingYun::Agent::TransactionState.tl_get
          TingYun::Agent::Transaction.wrap(state, "Message/RabbitMQ/localhost:3307%2FProduce%2FQueue%2Fbunny.examples.hello_world", :RabbitMq)  do
            publish_without_tingyun(payload, opts = {})
          end

        end

        alias_method :publish_without_tingyun, :publish
        alias_method :publish, :publish_with_tingyun
      end

    end
  end

end