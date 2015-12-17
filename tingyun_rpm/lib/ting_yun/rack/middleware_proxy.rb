# encoding: utf-8
require 'ting_yun/transaction/transaction_name'
require 'ting_yun/rack/middleware_tracing'


module TingYun
  module Rack
    class MiddlewareProxy
      include MiddlewareTracing

      attr_reader :target, :category, :transaction_options

      def initialize(target, is_app = false)
        @target               = target
        @is_app               = is_app
        @category             = @is_app? :rack : :middleware
        @target_class_name    =  @target.is_a?(Class)? @target.name : @target.class.name
        @transaction_name     = "#{determine_prefix}#{@target_class_name}/call"
        @transaction_options  = {
            :transaction_name => @transaction_name
        }
      end

      def determine_prefix
        TingYun::Agent::TransactionName.prefix_for_category(@category)
      end

      # This class is used to wrap classes that are passed to
      # Rack::Builder#use without synchronously instantiating those classes.
      # this MiddlewareProxy responds to new, like a Class would, and
      # passes through arguments to new to the original target class.
      def initialize(middleware_class)
        @middleware_class = middleware_class
      end

      def new(*args, &blk)
        middleware_instance = @middleware_class.new(*args, &blk)
        MiddlewareProxy.proxy(middleware_instance)
      end

      def self.proxy_middleware_class(target_class)
        MiddlewareProxy.new(target_class)
      end


      def self.proxy(target, is_app=false)
        need_proxy?(target) ? new(target, is_app) : target
      end

      def self.need_proxy?(target)
        !target.respond_to?(:_nr_has_middleware_tracing) && !sinatra_app?(target)
      end

      def sinatra_app?(target)
        defined?(::Sinatra::Base) && target.kind_of?(::Sinatra::Base)
      end


    end
  end
end
