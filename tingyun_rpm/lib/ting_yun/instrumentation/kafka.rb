# encoding: utf-8

TingYun::Support::LibraryDetection.defer do
  named :ruby_kafka

  depends_on do
    begin
      require 'kafka'
      defined?(::Kafka) && !TingYun::Agent.config[:disable_kafka]
    rescue LoadError
      false
    end
  end

  executes do
    TingYun::Agent.logger.info 'Installing Ruby-Kafka Instrumentation'
  end

  executes do
    Kafka::Producer.class_eval do
      attr_reader :cluster
    end

    if defined? (Kafka::Cluster)
      Kafka::Cluster.class_eval do
        attr_reader :seed_brokers
      end
    end

    if defined?(Kafka::AsyncProducer) && defined?(Kafka::AsyncProducer::Worker)
      Kafka::AsyncProducer::Worker.class_eval do
        attr_reader :producer
      end
    end

    Kafka::Client.class_eval do
      if public_method_defined? :deliver_message
        alias_method :deliver_message_without_tingyun, :deliver_message

        def deliver_message(*args, **options, &block)
          state = TingYun::Agent::TransactionState.tl_get
          ip_and_hosts = @seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue nil
          metric_name = "Message/Kafka/#{ip_and_hosts}%2FProduce%2FTopic%2F#{options[:topic]}"
          TingYun::Agent::Transaction.wrap(state, metric_name, :Kafka) do
            TingYun::Agent.record_metric("#{metric_name}/Byte",args[0].bytesize) if args[0]
            deliver_message_without_tingyun(*args, **options, &block)
          end
        end
      end

      if public_method_defined? :fetch_messages
        alias_method :fetch_messages_without_tingyun, :fetch_messages
        def fetch_messages(*args, **options, &block)
          state = TingYun::Agent::TransactionState.tl_get
          ip_and_hosts = @seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue nil
          metric_name = "Message/Kafka/#{ip_and_hosts}%2FConsumer%2FTopic%2F#{options[:topic]}"
          TingYun::Agent::Transaction.wrap(state, metric_name, :Kafka) do
            res = fetch_messages_without_tingyun(*args, **options, &block)
            bytesize = res.reduce(0){|res, msg| res += msg.value.bytesize}
            TingYun::Agent.record_metric("#{metric_name}/Byte", bytesize) if bytesize > 0
            res
          end
        end
      end
    end

    Kafka::Producer.class_eval do
      alias_method :produce_without_tingyun, :produce
      def produce(*args, **options, &block)
        state = TingYun::Agent::TransactionState.tl_get
        return produce_without_tingyun(*args, **options, &block) unless state.current_transaction
        ip_and_hosts = @cluster.seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue nil
        metric_name = "Message/Kafka/#{ip_and_hosts}%2FProduce%2FTopic%2F#{options[:topic]}"
        TingYun::Agent::Transaction.wrap(state, metric_name, :Kafka) do
          TingYun::Agent.record_metric("#{metric_name}/Byte",args[0].bytesize) if args[0]
          produce_without_tingyun(*args, **options, &block)
        end
      end
    end

    if defined?(Kafka::AsyncProducer)
      Kafka::AsyncProducer.class_eval do
        if public_method_defined? :produce
          alias_method :produce_without_tingyun, :produce

          def produce(*args, **options, &block)
            state = TingYun::Agent::TransactionState.tl_get
            ip_and_hosts = @worker.producer.cluster.seed_brokers.map{|a| [a.host, a.port].join(':')}.join(',') rescue nil
            metric_name = "Message/Kafka/#{ip_and_hosts}%2FProduce%2FTopic%2F#{options[:topic]}"
            TingYun::Agent::Transaction.wrap(state, metric_name, :Kafka) do
              TingYun::Agent.record_metric("#{metric_name}/Byte",args[0].bytesize) if args[0]
              produce_without_tingyun(*args, **options, &block)
            end
          end
        end
      end
    end
  end
end