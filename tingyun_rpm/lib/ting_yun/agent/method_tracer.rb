# encoding: utf-8

# This file may be independently required to set up method tracing prior to
# the full agent loading. In those cases, we do need at least this require to
# bootstrap things.

require 'ting_yun/frameworks' unless defined?(TingYun::Frameworks::Framework)
require 'ting_yun/support/helper'
require 'ting_yun/agent/method_tracer_helpers'

module TingYun
  module Agent

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
    #     require 'ting_yun/agent/method_tracer'
    #     class A
    #       include TingYun::Agent::MethodTracer
    #       def process
    #         ...
    #       end
    #       add_method_tracer :process
    #     end
    #
    # To instrument a class method:
    #
    #     require 'ting_yun/agent/method_tracer'
    #     class An
    #       def self.process
    #         ...
    #       end
    #       class << self
    #         include TingYun::Agent::MethodTracer
    #         add_method_tracer :process
    #       end
    #     end
    #
    # @api public
    module MethodTracer

      def self.included klass
        klass.extend ClassMethods
      end

      def self.extended klass
        klass.extend ClassMethods
      end


      def self.trace_execution_scoped(metric_names, options={}, callback = nil, klass_name=nil) #THREAD_LOCAL_ACCESS
        TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(metric_names, options, callback, klass_name) do
          # Using an implicit block avoids object allocation for a &block param
          yield
        end
      end

      # Defines methods used at the class level, for adding instrumentation
      # @api public
      module ClassMethods

        # contains methods refactored out of the #add_method_tracer method
        module AddMethodTracer
          # Checks to see if the method we are attempting to trace
          # actually exists or not. #add_method_tracer can't do
          # anything if the method doesn't exist.
          def _method_exists?(method_name)
            exists = method_defined?(method_name) || private_method_defined?(method_name)
            ::TingYun::Agent.logger.error("Did not trace #{self.name}##{method_name} because that method does not exist") unless exists
            exists
          end

          # Default to the class where the method is defined.
          #
          # Example:
          #  Foo.default_metric_name_code('bar') #=> "Tingyun/#{Foo.name}/bar"
          def default_metric_name_code(method_name)
            "Tingyun/#{self.name}/#{method_name.to_s}"
          end

          # Checks to see if we have already traced a method with a
          # given metric by checking to see if the traced method
          # exists. Warns the user if methods are being double-traced
          # to help with debugging custom instrumentation.
          def traced_method_exists?(method_name, metric_name_code)
            exists = method_defined?(_traced_method_name(method_name, metric_name_code))
            ::TingYun::Agent.logger.error("Attempt to trace a method twice with the same metric: Method = #{method_name}, Metric Name = #{metric_name_code}") if exists
            exists
          end

          # Decides which code snippet we should be eval'ing in this
          # context, based on the options.
          def code_to_eval(method_name, metric_name_code, options)
            options = validate_options(method_name, options)
            if options[:push_scope]
              method_with_push_scope(method_name, metric_name_code, options)
            else
              method_without_push_scope(method_name, metric_name_code, options)
            end
          end

          DEFAULT_SETTINGS = {:push_scope => true, :metric => true, :code_header => "", :code_footer => "" }.freeze

          # Checks the provided options to make sure that they make
          # sense. Raises an error if the options are incorrect to
          # assist with debugging, so that errors occur at class
          # construction time rather than instrumentation run time
          def validate_options(method_name, options)
            unless options.is_a?(Hash)
              raise TypeError.new("Error adding method tracer to #{method_name}: provided options must be a Hash")
            end
            options = DEFAULT_SETTINGS.merge(options)
            check_for_push_scope_and_metric(options)
            options
          end

          def check_for_push_scope_and_metric(options)
            unless options[:push_scope] || options[:metric]
              raise "Can't add a tracer where push_scope is false and metric is false"
            end
          end

          # returns an eval-able string that contains the tracing code
          # for a fully traced metric including scoping
          def method_with_push_scope(method_name, metric_name_code, options)
            "def #{_traced_method_name(method_name, metric_name_code)}(*args, &block)
              #{options[:code_header]}
              result = ::TingYun::Agent::MethodTracerHelpers.trace_execution_scoped(\"#{metric_name_code}\",
                        :metric => #{options[:metric]}) do
                #{_untraced_method_name(method_name, metric_name_code)}(*args, &block)
              end
              #{options[:code_footer]}
              result
            end"
          end

          # returns an eval-able string that contains the traced
          # method code used if the agent is not creating a scope for
          # use in scoped metrics.
          def method_without_push_scope(method_name, metric_name_code, options)
            "def #{_traced_method_name(method_name, metric_name_code)}(*args, &block)
              #{assemble_code_header(method_name, metric_name_code, options)}
              t0 = Time.now
              begin
                #{_untraced_method_name(method_name, metric_name_code)}(*args, &block)\n
              ensure
                duration = (Time.now - t0).to_f
                ::TingYun::Agent.record_metric(\"#{metric_name_code}\", duration)
                #{options[:code_footer]}
              end
            end"
          end

          # Returns a code snippet to be eval'd that skips tracing
          # when the agent is not tracing execution. turns
          # instrumentation into effectively one method call overhead
          # when the agent is disabled
          def assemble_code_header(method_name, metric_name_code, options)
            # header = "return #{_untraced_method_name(method_name, metric_name_code)}(*args, &block) unless TingYun::Agent.tl_is_execution_traced?\n"
            header += options[:code_header].to_s
            header
          end



        end
        include AddMethodTracer


        # Add a method tracer to the specified method.
        #
        # By default, this will cause invocations of the traced method to be
        # recorded in transaction traces, and in a metric named after the class
        # and method. It will also make the method show up in transaction-level
        # breakdown charts and tables.
        #
        # === Overriding the metric name
        #
        # +metric_name_code+ is a string that is eval'd to get the name of the
        # metric associated with the call, so if you want to use interpolation
        # evaluated at call time, then single quote the value like this:
        #
        #     add_method_tracer :foo, 'Tingyun/#{self.class.name}/foo'
        #
        # This would name the metric according to the class of the runtime
        # intance, as opposed to the class where +foo+ is defined.
        #
        # If not provided, the metric name will be <tt>Custom/ClassName/method_name</tt>.
        #
        # @param [Symbol] method_name the name of the method to trace
        # @param [String] metric_name_code the metric name to record calls to
        #   the traced method under. This may be either a static string, or Ruby
        #   code to be evaluated at call-time in order to determine the metric
        #   name dynamically.
        # @param [Hash] options additional options controlling how the method is
        #   traced.
        # @option options [Boolean] :push_scope (true) If false, the traced method will
        #   not appear in transaction traces or breakdown charts, and it will
        #   only be visible in custom dashboards.
        # @option options [Boolean] :metric (true) If false, the traced method will
        #   only appear in transaction traces, but no metrics will be recorded
        #   for it.
        # @option options [String] :code_header ('') Ruby code to be inserted and run
        #   before the tracer begins timing.
        # @option options [String] :code_footer ('') Ruby code to be inserted and run
        #   after the tracer stops timing.
        #
        # @example
        #   add_method_tracer :foo
        #
        #   # With a custom metric name
        #   add_method_tracer :foo, 'Tingyun/#{self.class.name}/foo'
        #
        #   # Instrument foo only for custom dashboards (not in transaction
        #   # traces or breakdown charts)
        #   add_method_tracer :foo, 'Tingyun/foo', :push_scope => false
        #
        #   # Instrument foo in transaction traces only
        #   add_method_tracer :foo, 'Tingyun/foo', :metric => false
        #
        # @api public
        #
        def add_method_tracer(method_name, metric_name_code=nil, options = {})
          return unless _method_exists?(method_name)
          metric_name_code ||= default_metric_name_code(method_name)
          return if traced_method_exists?(method_name, metric_name_code)

          traced_method = code_to_eval(method_name, metric_name_code, options)

          visibility = TingYun::Helper.instance_method_visibility self, method_name

          class_eval traced_method, __FILE__, __LINE__
          alias_method _untraced_method_name(method_name, metric_name_code), method_name
          alias_method method_name, _traced_method_name(method_name, metric_name_code)
          send visibility, method_name
          send visibility, _traced_method_name(method_name, metric_name_code)
          ::TingYun::Agent.logger.debug("Traced method: class = #{self.name},"+
                                             "method = #{method_name}, "+
                                             "metric = '#{metric_name_code}'")
        end

        private

        # given a method and a metric, this method returns the
        # untraced alias of the method name
        def _untraced_method_name(method_name, metric_name)
          "#{_sanitize_name(method_name)}_without_trace_#{_sanitize_name(metric_name)}"
        end

        # given a method and a metric, this method returns the traced
        # alias of the method name
        def _traced_method_name(method_name, metric_name)
          "#{_sanitize_name(method_name)}_with_trace_#{_sanitize_name(metric_name)}"
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

