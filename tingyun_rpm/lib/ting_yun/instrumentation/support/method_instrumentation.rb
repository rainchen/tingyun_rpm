# encoding: utf-8
require 'ting_yun/frameworks' unless defined?(TingYun::Frameworks::Framework)
require 'ting_yun/support/helper'
require 'ting_yun/agent/method_tracer_helpers'
require 'ting_yun/agent/transaction/transaction_state'

module TingYun
  module Instrumentation
    module Support
      module MethodInstrumentation

        # This module contains class methods added to support installing custom
        # metric tracers and executing for individual metrics.
        #
        # == Examples
        #
        # When the agent initializes, it extends Module with these methods.
        # However if you want to use the API in code that might get loaded
        # before the agent is initialized you will need to require
        # this file:
        #
        #     require 'ting_yun/instrumentation/support/method_instrumentation'
        #     class A
        #       include TingYun::Instrumentation::Support::MethodInstrumentation
        #       def process
        #         ...
        #       end
        #       add_method_tracer :process
        #     end
        #
        # To instrument a class method:
        #
        #      require 'ting_yun/instrumentation/support/method_instrumentation'
        #     class An
        #       def self.process
        #         ...
        #       end
        #       class << self
        #         include TingYun::Instrumentation::Support::MethodInstrumentation
        #         add_method_tracer :process
        #       end
        #     end
        #
        # @api public

        def self.included(klass)
          klass.extend ClassMethods
        end

        def self.extended(klass)
          klass.extend ClassMethods
        end

        module ClassMethods
          def method_exists?(method_name)
            exists = method_defined?(method_name) || private_method_defined?(method_name)
            ::TingYun::Agent.logger.error("Did not trace #{self.name}##{method_name} because that method does not exist") unless exists
            exists
          end

          # Example:
          #  Foo.default_metric_name('bar') #=> "tingyun/#{Foo.name}/bar"
          def default_metric_name(method_name)
            "tingyun/#{self.name}/#{method_name.to_s}"
          end


          # Checks to see if we have already traced a method with a
          # given metric by checking to see if the traced method
          # exists. Warns the user if methods are being double-traced
          # to help with debugging custom instrumentation.
          def traced_method_exists?(method_name, metric_name)
            exists = method_defined?(define_trace_method_name(method_name, metric_name))
            ::TingYun::Agent.logger.error("Attempt to trace a method twice with the same metric: Method = #{method_name}, Metric Name = #{metric_name}") if exists
            exists
          end

          def tingyun_eval(method_name, metric_name, options)
            options = validate_options(method_name, options)
            if options[:scope]
              define_method_with_scope(method_name, metric_name, options)
            else
              define_method_without_scope(method_name,metric_name, options)
            end
          end

          DEFAULT_SETTINGS = {:scope => true, :metric => true, :before_code => "", :after_code => "" }.freeze

          def validate_options(method_name, options)
            unless options.is_a?(Hash)
              raise TypeError.new("Error adding method tracer to #{method_name}: provided options must be a Hash")
            end
            options = DEFAULT_SETTINGS.merge(options)
            unless options[:scope] || options[:metric]
              raise "Can't add a tracer where push_scope is false and metric is false"
            end
            options
          end

          def define_method_with_scope(method_name,metric_name,options)
            "def #{define_trace_method_name(method_name,metric_name)}(*args, &block)
                #{options[:before_code]}

                result = ::TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(\"#{metric_name}\",
                        :metric => #{options[:metric]}) do
                  #{define_untrace_method_name(method_name, metric_name)}(*args, &block)
                end
                #{options[:after_code]}
                result
             end"
          end

          def define_method_without_scope(method_name,metric_name,options)
            "def #{define_trace_method_name(method_name,metric_name)}(*args, &block)
                return #{define_untrace_method_name(method_name, metric_name)}(*args, &block) unless TingYun::Agent::TransactionState.tl_get.execution_traced?\n
            #{options[:before_code]}
                t0 = Time.now
                begin
                  #{define_untrace_method_name(method_name, metric_name)}(*args, &block)\n
                ensure
                  duration = (Time.now - t0).to_f
                  ::TingYun::Agent.record_metric(\"#{metric_name}\", duration)
                  #{options[:after_code]}
                end
             end"
          end

          #
          #
          #   第一个参数是需要跟踪的方法，第二个是需要在报表上显示的方法metric_name. 默认值“tingyun/class_name/method_name”
          #   options接受4个参数，默认值
          #   {:scope => true, :metric => true, :before_code=> "", :after_code => "" }
          #
          #   scope为false的时候，只有general的数据
          #
          #   metirc为false的时候，数据只会在actionTraceData存在
          #
          #
          #   before_code 和 after_code是可执行的Ruby代码。分别在被监测的方法开始前和结束后执行4
          def add_method_tracer(method_name, metric_name = nil, opt={})
            return unless method_exists?(method_name)
            metric_name ||= default_metric_name(method_name)
            return if traced_method_exists?(method_name, metric_name)

            traced_method = tingyun_eval(method_name, metric_name,opt)

            visibility = TingYun::Helper.instance_method_visibility self, method_name
            class_eval traced_method, __FILE__, __LINE__

            alias_method define_untrace_method_name(method_name, metric_name), method_name
            alias_method method_name, define_trace_method_name(method_name, metric_name)
            send visibility, method_name
            send visibility, define_trace_method_name(method_name, metric_name)
            ::TingYun::Agent.logger.debug("Traced method: class = #{self.name},"+
                                              "method = #{method_name}, "+
                                              "metric = '#{metric_name}'")
          end

          private
          # given a method and a metric, this method returns the
          # traced alias of the method name
          def define_trace_method_name(method_name, metric_name)
            "#{_sanitize_name(method_name)}_with_trace_#{_sanitize_name(metric_name)}"
          end
          # given a method and a metric, this method returns the
          # untraced alias of the method name
          def define_untrace_method_name(method_name, metric_name)
            "#{_sanitize_name(method_name)}_without_trace_#{_sanitize_name(metric_name)}"
          end

          # makes sure that method names do not contain characters that
          # might break the interpreter, for example ! or ? characters
          # that are not allowed in the middle of method names
          def _sanitize_name(name)
            name.to_s.tr_s('^a-zA-Z0-9', '_')
          end
        end
      end
    end
  end
end


