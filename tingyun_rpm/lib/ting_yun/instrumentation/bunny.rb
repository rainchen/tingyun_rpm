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
          queue_name = opts[:routing_key]
          opts['TingyunID'] = "#{TingYun::Agent.config[:tingyunIdSecret]};c=1;x=#{state.request_guid};e=#{state.request_guid}"
          metric_name = "Message/RabbitMQ/#{@channel.connection.host}:#{@channel.connection.port}%2FProduce%2FQueue%2F#{name}-#{queue_name}"
          TingYun::Agent::Transaction.wrap(state, metric_name , :RabbitMq)  do
            TingYun::Agent.record_metric("#{metric_name}/Byte",payload.bytesize) if payload
            publish_without_tingyun(payload, opts)
          end
        end

        alias_method :publish_without_tingyun, :publish
        alias_method :publish, :publish_with_tingyun
      end

    end
  end

end