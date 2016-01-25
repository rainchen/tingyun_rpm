# encoding: utf-8



TingYun::Support::LibraryDetection.defer do
  named :redis

  depends_on do
    defined?(::Redis)
  end


  executes do
    TingYun::Agent.logger.info 'Installing Redis Instrumentation'
  end

  executes do
    require 'ting_yun/agent/datastore'

    ::Redis::Client.class_eval do


      call_method = ::Redis::Client.new.respond_to?(:call) ? :call : :raw_call_command

      def call_with_tingyun_trace(*args, &blk)
        operation = args[0].is_a?(Array) ? args[0][0] : args[0]

        TingYun::Agent::Datastore.wrap("Redis", operation) do
          call_without_tingyun_trace(*args, &blk)
        end
      end

      alias_method :call_without_tingyun_trace, call_method
      alias_method call_method, :call_with_tingyun_trace


      if public_method_defined? :call_pipelined
        def call_pipelined_with_tingyun_trace(*args, &block)
          pipeline = args[0]
          operation = pipeline.is_a?(::Redis::Pipeline::Multi) ? 'multi' : 'pipeline'

          TingYun::Agent::Datastore.wrap("Redis", operation) do
            call_pipelined_without_tinyun_trace(*args, &block)
          end
        end

        alias_method :call_pipelined_without_tingyun_trace, :call_pipelined
        alias_method :call_pipelined, :call_pipelined_with_tingyun_trace
      end

      if public_method_defined? :connect

        alias_method :connect_without_tingyun, :connect

        def connect(*args, &block)
          NewRelic::Agent::Datastores.wrap("Redis", "connect") do
            connect_without_tingyun(*args, &block)
          end
        end
      end
    end
  end
end