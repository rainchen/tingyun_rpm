# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/logger/agent_logger'
require 'ting_yun/agent/class_methods'
require 'ting_yun/agent/instance_methods'
require 'ting_yun/ting_yun_service'




# The Agent is a singleton that is instantiated when the plugin is
# activated.  It collects performance data from ruby applications
# in realtime as the application runs, and periodically sends that
# data to the  server. TingYun::Agent::Agent.instance

module TingYun
  module Agent
    class Agent

      # service for communicating with collector
      attr_accessor :service

      extend ClassMethods
      include InstanceMethods


      def start
        return unless agent_should_start?
        log_the_startup
        check_config_and_start_the_agent
        log_version_and_pid
      end

      # Attempt a graceful shutdown of the agent, flushing any remaining
      # data.
      def shutdown
        return unless started?
        TingYun::Agent.logger.info "Starting Agent shutdown"
        reset_to_default_configuration
        @started = nil
      end

      # Connect to the server and validate the license.  If successful,
      # connected? returns true when finished.  If not successful, you can
      # keep calling this.  Return false if we could not establish a
      # connection with the server and we should not retry, such as if
      # there's a bad license key.

      def connect(option={})
        keep_retrying_or_force_reconnect?(option) do
          TingYun::Agent.logger.debug "Connecting Process to Ting Yun: #$0"
          query_server_for_configuration #connnect
          @connected_pid = $$
          @connect_state = :connected
        end
      end

      private

      def initialize
        @started = false
        @environment_report = nil
        @service = TingYunService.new
        @connect_state = :pending #[:pending, :connected, :disconnected]
        @connect_attempts = 0
      end
    end
  end
end