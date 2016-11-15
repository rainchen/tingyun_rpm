# encoding: utf-8

TingYun::Support::LibraryDetection.defer do
  named :memcached

  depends_on do
    defined?(::Memcached)
  end


  executes do
    TingYun::Agent.logger.info 'Installing Memcached Instrumentation'
    require 'ting_yun/agent/transaction/transaction_state'
  end

  executes do
    require 'ting_yun/agent/datastore'

    ::Memcached.class_eval do

      def record_memcached_duration(_1, _2, duration)
        state = TingYun::Agent::TransactionState.tl_get
        if state
          state.timings.memchd_duration = state.timings.memchd_duration + duration * 1000
        end
      end

      methods = [:set, :add, :increment, :decrement, :replace, :append, :prepend, :cas,
                 :delete, :flush, :get, :exist, :get_from_last, :server_by_key, :stats]

      methods.each do |method|
        next unless public_method_defined? method

        alias_method "#{method}_without_tingyun_trace".to_sym, method.to_sym

        define_method method do |*args, &block|
          TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
            send "#{method}_without_tingyun_trace", *args, &block
          end
        end
      end

      alias :incr :increment
      alias :decr :decrement
      alias :compare_and_swap :cas if public_method_defined? :compare_and_swap
    end
  end
end