# encoding: utf-8

TingYun::Support::LibraryDetection.defer do
  named :dalli

  depends_on do
    defined?(::Dalli) && defined?(::Dalli::Client) && Rails::VERSION::MAJOR.to_i >= 3
  end


  executes do
    TingYun::Agent.logger.info 'Installing Dalli Instrumentation'
    require 'ting_yun/agent/transaction/transaction_state'
  end

  executes do
    require 'ting_yun/agent/datastore'
    require 'ting_yun/instrumentation/support/timings'

    ::Dalli::Server.class_eval do

      include TingYun::Instrumentation::Support::Timings

      private
      alias_method :connect_without_tingyun_trace, :connect
      def connect
        TingYun::Agent::Datastore.wrap('Memcached', 'connect', nil, method(:record_memcached_duration)) do
          connect_without_tingyun_trace
        end
      end
    end

    ::Dalli::Client.class_eval do

      include TingYun::Instrumentation::Support::Timings

      methods = [:multi, :get, :get_multi, :cas, :cas!, :set, :add, :replace, :delete, :append, :prepend, :flush,
                 :incr, :decr, :touch, :stats, :reset_stats, :alive!, :version, :close, :with, :get_cas, :get_multi_cas,
                 :set_cas, :replace_cas, :delete_cas]
      methods.each do |method|
        next unless public_method_defined? method
        alias_method "#{method}_without_tingyun_trace".to_sym, method.to_sym

        define_method method do |*args, &block|
          TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
            send "#{method}_without_tingyun_trace", *args, &block
          end
        end
      end

      alias :flush_all :flush
      alias :reset :close
    end
  end
end