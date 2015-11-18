# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent/instance_methods/start'
require 'ting_yun/agent/instance_methods/connect'

module TingYun
  module Agent
    module InstanceMethods

      # service for communicating with collector
      attr_accessor :service

      include Start
      include Connect


      def started?
        @started
      end


      # Check to see if the agent should start, returning +true+ if it should.
      def agent_should_start?
        return false if already_started? || disabled?
        unless app_name_configured?
          Agent.logger.error "No application name configured.",
                             "The Agent cannot start without at least one. Please check your ",
                             "tingyun.yml and ensure that it is valid and has at least one ",
                             "value set for app_name in the",
                             "environment."
          return false
        end
        return true
      end

      def reset_to_default_configuration
        Agent.config.remove_config_type(:manual)
        Agent.config.remove_config_type(:server)
      end

      def drop_the_buffered_data

      end


    end
  end
end