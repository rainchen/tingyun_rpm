# encoding: utf-8



TingYun::Support::LibraryDetection.defer do
  named :thrift

  depends_on do
    defined?(::Thrift) && defined?(::Thrift::Client)
  end


  executes do
    TingYun::Agent.logger.info 'Installing Thrift Instrumentation'
  end

  executes do
    ::Thrift::Client.module_eval do
      def send_message_with_tingyun

      end

      def send_message_without_tingyun

      end

      alias :send_message_without_tingyun :send_message
      alias :send_message  :send_message_with_tingyun
    end
  end

end