# encoding: utf-8



TingYun::Support::LibraryDetection.defer do
  named :memcache_client

  depends_on do
    # require 'memcache'
    # defined?(::MemCache)
    false
  end


  executes do
    TingYun::Agent.logger.info 'Installing MemCache Client Instrumentation'
    require 'ting_yun/agent/transaction/transaction_state'
  end

  executes do
    require 'ting_yun/agent/datastore'

    ::MemCache.class_eval do

      def record_memcached_duration(_1, _2, duration)
        state = TingYun::Agent::TransactionState.tl_get
        if state
          state.timings.memchd_duration = state.timings.memchd_duration + duration * 1000
        end
      end

      # methods = [:fetch, :flush_all, :reset, :stats, :[], :[]=]
      methods = [:decr, :get, :get_multi, :incr, :set, :cas, :add, :replace, :append, :prepend, :delete]

      methods.each do |method|
        alias_method "#{method}_without_tingyun_trace".to_sym, method.to_sym

        case method
          when :decr, :incr
            define_method method do |key, amount = 1|
              TingYun::Agent::Datastore.wrap('MemCacheClient', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, amount
              end
            end
          when :set, :add, :replace
            define_method method do |key, value, expiry = 0, raw = false|
              TingYun::Agent::Datastore.wrap('MemCacheClient', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, value, expiry, raw
              end
            end
          when :get
            define_method method do |key, raw = false|
              TingYun::Agent::Datastore.wrap('MemCacheClient', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, raw
              end
            end
          when :get_multi
            define_method method do |*keys|
              TingYun::Agent::Datastore.wrap('MemCacheClient', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", *keys
              end
            end
          when :cas
            define_method method do |key, expiry=0, raw=false|
              TingYun::Agent::Datastore.wrap('MemCacheClient', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, expiry, raw
              end
            end
          when :append, :prepend
            define_method method do |key, value|
              TingYun::Agent::Datastore.wrap('MemCacheClient', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, value
              end
            end
          when :delete
            define_method method do |key, expiry = 0|
              TingYun::Agent::Datastore.wrap('MemCacheClient', method.to_s, nil, method(:record_memcached_duration)) do
                send "#{method}_without_tingyun_trace", key, expiry
              end
            end
        end
      end
    end
  end
end