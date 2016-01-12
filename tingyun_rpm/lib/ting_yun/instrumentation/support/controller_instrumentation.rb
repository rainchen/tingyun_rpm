# encoding: utf-8

module TingYun
  module Instrumentation
    module Support

      # ==  instrumentation for controller actions and tasks
      #
      # This module can also be used to capture performance information for
      # background tasks and other non-web transactions, including
      # detailed transaction traces and traced errors.
      #
      # For details on how to instrument background tasks see
      # {ClassMethods#add_transaction_tracer} and
      # {#perform_action_with_newrelic_trace}
      #
      # @api public
      #
      module ControllerInstrumentation

        def self.included(klass) # :nodoc:
          klass.extend(ClassMethods)
        end

        module ClassMethods

        end
      end
    end
  end
end
