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

      # methods = [:incr, :decr, :compare_and_swap]
      methods = [:set, :add, :increment, :decrement, :replace, :append, :prepend, :cas,
                 :delete, :flush, :get, :exist, :get_from_last, :server_by_key, :stats]
      methods.each do |method|
        alias_method "#{method}_without_tingyun_trace".to_sym, method.to_sym

        case method
          when :set, :add, :replace
            define_method method do |key, value, ttl=@default_ttl, encode=true, flags=Memcached::FLAGS|
              TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, value, ttl, encode, flags
              end
            end
          when :increment, :decrement
            define_method method do |key, offset=1|
              TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, offset
              end
            end
          when :append, :prepend
            define_method method do |key, value|
              TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, value
              end
            end
          when :cas
            define_method method do |keys, ttl=@default_ttl, decode=true|
              TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", keys, ttl, decode
              end
            end
          when :flush
            define_method method do
              TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace"
              end
            end
          when :delete, :exist, :server_by_key
            define_method method do |key|
              TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key
              end
            end
          when :get, :get_from_last
            define_method method do |keys, decode=true|
              TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", keys, decode
              end
            end
          when :stats
            define_method method do |subcommand = nil|
              TingYun::Agent::Datastore.wrap('Memcached', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", subcommand
              end
            end
        end
      end
    end
  end
end