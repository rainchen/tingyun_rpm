# encoding: utf-8
module TingYun
  module Instrumentation
    module Timings
      def record_memcached_duration(_1, _2, duration)
        state = TingYun::Agent::TransactionState.tl_get
        if state
          state.timings.mc_duration = state.timings.mc_duration + duration * 1000
        end
      end
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  named :memcached

  depends_on do
    defined?(::Memcached) || (defined?(::Dalli) && defined?(::Dalli::Client))
  end


  executes do
    TingYun::Agent.logger.info "Installing Memcached Instrumentation" if defined?(::Memcached)
    TingYun::Agent.logger.info "Installing Dalli Instrumentation" if defined?(::Dalli::Client)
    require 'ting_yun/agent/transaction/transaction_state'
  end

  executes do
    require 'ting_yun/agent/datastore'

    if defined?(::Memcached)
      ::Memcached.class_eval do

        include TingYun::Instrumentation::Timings

        methods = [:set, :add, :increment, :decrement, :replace, :append, :prepend, :cas, :delete, :flush, :get, :exist,
                   :get_from_last, :server_by_key, :stats, :set_servers]

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

    if defined?(::Dalli::Server)
      ::Dalli::Server.class_eval do

        include TingYun::Instrumentation::Timings

        connect_method = (private_method_defined? :connect) ? :connect : :connection
        private
        alias_method :connect_without_tingyun_trace, connect_method

        define_method connect_method do |*args, &block|
          if @sock
            connect_without_tingyun_trace *args, &block
          else
            TingYun::Agent::Datastore.wrap('Memcached', 'connect', nil, method(:record_memcached_duration)) do
              connect_without_tingyun_trace *args, &block
            end
          end
        end
      end
    end

    if defined?(::Dalli::Client)
      ::Dalli::Client.class_eval do

        include TingYun::Instrumentation::Timings

        methods = [:get, :get_multi, :cas, :cas!, :set, :add, :replace, :delete, :append, :prepend, :flush, :incr, :decr,
                   :touch, :stats, :reset_stats, :close, :get_cas, :get_multi_cas, :set_cas, :replace_cas, :delete_cas]
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
        alias :reset :close if public_method_defined? :reset
      end
    end
  end
end