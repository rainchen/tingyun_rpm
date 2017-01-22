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
          begin
            state = TingYun::Agent::TransactionState.tl_get
            queue_name = opts[:routing_key]
            opts[:headers] = {} unless opts[:headers]
            opts[:headers][:TingyunID] = "#{TingYun::Agent.config[:tingyunIdSecret]};c=1;x=#{state.request_guid};e=#{state.request_guid}"
            metric_name = "Message/RabbitMQ/#{@channel.connection.host}:#{@channel.connection.port}%2FProduce%2FQueue%2F#{name}-#{queue_name}"
            TingYun::Agent::Transaction.wrap(state, metric_name , :RabbitMq)  do
              TingYun::Agent.record_metric("#{metric_name}/Byte",payload.bytesize) if payload
              publish_without_tingyun(payload, opts)
            end
          rescue => e
            TingYun::Agent.logger.error("Failed to Bunny publish_with_tingyun : ", e)
            publish_without_tingyun(payload, opts)
          end
        end

        alias_method :publish_without_tingyun, :publish
        alias_method :publish, :publish_with_tingyun
      end

    end

    ::Bunny::Consumer.class_eval do

      if public_method_defined? :call

        def call_with_tingyun(*args)
          begin
            cross_app_enabled?(args[1]&&args[1][:headers]&&args[1][:headers]["TingyunID"])
            state = TingYun::Agent::TransactionState.tl_get
            metric_name = "Message/RabbitMQ/#{@channel.connection.host}:#{@channel.connection.port}%2FConsume%2FQueue%2F#{queue_name}"
            Tin Yun::Agent::Transaction.start(state,:message, { :transaction_name => "WebAction/#{metric_name}"})
            TingYun::Agent::Transaction.wrap(state, metric_name , :RabbitMq)  do
              TingYun::Agent.record_metric("#{metric_name}/Byte",args[2].bytesize) if args[2]
              call_without_tingyun(*args)
            end
          rescue => e
            TingYun::Agent.logger.error("Failed to Bunny call_with_tingyun : ", e)
            call_without_tingyun(*args)
          ensure
            TingYun::Agent::Transaction.stop(state)
          end

        end
        alias_method :call_without_tingyun, :call
        alias_method :call, :call_with_tingyun
      end

      def cross_app_enabled?(tingyun_id_secret)
        tingyun_id_secret && ::TingYun::Agent.config[:tingyunIdSecret] && tingyun_id_secret.start_with?(::TingYun::Agent.config[:tingyunIdSecret])
      end
    end
  end

end