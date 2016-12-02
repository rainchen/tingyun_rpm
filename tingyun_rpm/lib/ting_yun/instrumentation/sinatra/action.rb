# encoding: utf-8

require 'ting_yun/instrumentation/support/split_controller'
module TingYun
  module Instrumentation
    module Sinatra
      module Action

        include TingYun::Instrumentation::Support::SplitController

        def tingyun_metric_path(current_class)
          if find_rule(request.request_method.upcase, request.path, request.env, request.params)
            return "Sinatra/#{current_class}/#{namespace}/#{name(request.path.slice(1..-1), request.env, request.params, request.cookies)}"
          else
            return self.env["PATH_INFO"] unless TingYun::Agent.config[:'nbs.auto_action_naming']
            "Sinatra/#{current_class}#{request.path}(#{request.request_method.upcase})"
          end
        end
      end
    end
  end
end


TingYun::Support::LibraryDetection.defer do
  @name = :sinatra_action

  depends_on do
    defined?(::Sinatra) && defined?(::Sinatra::Base)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Sinatra action instrumentation'
  end

  executes do
    ::Sinatra::Base.class_eval do
      private
      alias :route_eval_without_tingyun_trace :route_eval
      alias :static_without_tingyun_trace! :static!

      def route_eval(*args, &block)

        self.class.class_eval do
          require 'ting_yun/instrumentation/support/parameter_filtering'
          require 'ting_yun/instrumentation/support/controller_instrumentation'
          include TingYun::Instrumentation::Sinatra::Action
        end

        params = TingYun::Instrumentation::Support::ParameterFiltering.flattened_filter_request_parameters(@params)
        TingYun::Instrumentation::Support::ControllerInstrumentation.perform_action_with_tingyun_trace(
            :category => :sinatra,
            :name     => @request.env['REQUEST_PATH'],
            :path     => tingyun_metric_path(self.class.name),
            :params   => params,
            :class_name => self.class.name,
            :request => @request
        ) do
          route_eval_without_tingyun_trace(*args, &block)
        end
      end
    end
  end
end
