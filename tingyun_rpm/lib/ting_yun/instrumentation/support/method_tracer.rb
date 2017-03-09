# encoding: utf-8
require 'ting_yun/support/helper'
require 'ting_yun/agent/method_tracer_helpers'

module TingYun
  module Instrumentation
    module Support
      module MethodTracer

        def self.included(klass)
          klass.extend ClassMethods
        end

        def self.extended(klass)
          klass.extend ClassMethods
        end

        module ClassMethods
          def add_method_tracer(method_name,opt={})
            visibility = TingYun::Helper.instance_method_visibility self, method_name

          end

          def tingyun_eval(method_name, opt)

          end
        end
      end
    end
  end
end


