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
            return publish_without_tingyun(payload, opts) unless state.current_transaction
            queue_name = opts[:routing_key]
            opts[:headers] = {} unless opts[:headers]
            externel_guid = tingyun_externel_guid
            state.transaction_sample_builder.current_node["externalId"] = externel_guid
            opts[:headers][:TingyunID] = "#{TingYun::Agent.config[:tingyunIdSecret]};c=1;x=#{state.request_guid};e=#{externel_guid}"
            metric_name = "Message RabbitMQ/#{@channel.connection.host}:#{@channel.connection.port}%2FQueue%2F#{name}-#{queue_name}/Produce"
            summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('RabbitMQ', "#{@channel.connection.host}:#{@channel.connection.port}", 'Produce')
            TingYun::Agent::Transaction.wrap(state, metric_name , :RabbitMq, {}, summary_metrics)  do
              TingYun::Agent.record_metric("#{metric_name}/Byte",payload.bytesize) if payload
              publish_without_tingyun(payload, opts)
            end
          rescue => e
            TingYun::Agent.logger.error("Failed to Bunny publish_with_tingyun : ", e)
            publish_without_tingyun(payload, opts)
          end
        end


        # generate a random 64 bit uuid
        def tingyun_externel_guid
          guid = ''
          16.times do
            guid << (0..15).map{|i| i.to_s(16)}[rand(16)]
          end
          guid
        end

        alias_method :publish_without_tingyun, :publish
        alias_method :publish, :publish_with_tingyun
      end

    end

    ::Bunny::Consumer.class_eval do

      if public_method_defined? :call

        def call_with_tingyun(*args)
          begin
            tingyun_id_secret = args[1]&&args[1][:headers]&&args[1][:headers]["TingyunID"]
            state = TingYun::Agent::TransactionState.tl_get
            metric_name = "#{@channel.connection.host}:#{@channel.connection.port}%2FQueue%2F#{queue_name}/Consume"
            summary_metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for_message('RabbitMQ', "#{@channel.connection.host}:#{@channel.connection.port}", 'Consume')
            TingYun::Agent::Transaction.start(state,:message, { :transaction_name => "WebAction/Message/RabbitMQ/#{metric_name}"})
            state.save_referring_transaction_info(tingyun_id_secret.split(';')) if cross_app_enabled?(tingyun_id_secret)
            TingYun::Agent::Transaction.wrap(state, "Message RabbitMQ/#{metric_name}" , :RabbitMq, {}, summary_metrics)  do
              TingYun::Agent.record_metric("Message RabbitMQ/#{metric_name}/Byte",args[2].bytesize) if args[2]
              call_without_tingyun(*args)
              state.current_transaction.attributes.add_agent_attribute(:entryTrace, build_payload(state)) if state.same_account?
            end
          rescue => e
            TingYun::Agent.logger.error("Failed to Bunny call_with_tingyun : ", e)
            call_without_tingyun(*args)
          ensure
            TingYun::Agent::Transaction.stop(state, Time.now, summary_metrics)
          end

        end
        alias_method :call_without_tingyun, :call
        alias_method :call, :call_with_tingyun
      end

      def cross_app_enabled?(tingyun_id_secret)
        tingyun_id_secret && ::TingYun::Agent.config[:tingyunIdSecret]
      end

      def build_payload(state)
        timings = state.timings
        payload = {
            :applicationId => TingYun::Agent.config[:tingyunIdSecret].split('|')[1],
            :transactionId => state.client_transaction_id,
            :externalId => state.extenel_req_id,
            :time => {
                :duration => timings.app_time_in_millis,
                :qu => timings.queue_time_in_millis,
                :db => timings.sql_duration,
                :ex => timings.external_duration,
                :rds => timings.rds_duration,
                :mc => timings.mc_duration,
                :mon => timings.mon_duration,
                :code => timings.app_execute_duration
            }
        }
      end

    end
  end

end