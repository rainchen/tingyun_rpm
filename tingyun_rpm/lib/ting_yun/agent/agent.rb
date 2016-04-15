# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/logger/agent_logger'
require 'ting_yun/agent/class_methods'
require 'ting_yun/agent/instance_methods'
require 'ting_yun/ting_yun_service'
require 'ting_yun/frameworks'
require 'ting_yun/agent/event/event_listener'
require 'ting_yun/agent/dispatcher'
require 'ting_yun/agent/collector/middle_ware_collector'


# The Agent is a singleton that is instantiated when the plugin is
# activated.  It collects performance data from ruby applications
# in realtime as the application runs, and periodically sends that
# data to the  server. TingYun::Agent::Agent.instance

module TingYun
  module Agent
    class Agent

      class << self
        private :new
      end

      # service for communicating with collector
      attr_accessor :service
      attr_reader :events

      extend ClassMethods
      include InstanceMethods




      def start
        # should hava the vaild app_name, unstart-state and able to start
        return unless agent_should_start?
        log_startup
        check_config_and_start_agent
        log_version_and_pid
      end

      # Attempt a graceful shutdown of the agent, flushing any remaining
      # data.
      def shutdown
        return unless started?
        TingYun::Agent.logger.info "Starting Agent shutdown"

        stop_event_loop
        reset_to_default_configuration

        @started = nil

        TingYun::Frameworks::Framework.reset
      end

      # Connect to the server and validate the license.  If successful,
      # connected? returns true when finished.  If not successful, you can
      # keep calling this.  Return false if we could not establish a
      # connection with the server and we should not retry, such as if
      # there's a bad license key.

      def connect!(option={})
        defaults = {
            :keep_retrying => ::TingYun::Agent.config[:keep_retrying],
            :force_reconnect => ::TingYun::Agent.config[:force_reconnect]
        }
        opts = defaults.merge(option)
        return unless should_connect?(opts[:force_reconnect])
        TingYun::Agent.logger.debug "Connecting Process to Ting Yun: #$0"
        query_server_for_configuration
        @connected_pid = $$
        @connect_state = :connected
      rescue TingYun::Support::Exception::LicenseException => e
        handle_license_error(e)
      rescue TingYun::Support::Exception::UnrecoverableAgentException => e
        handle_unrecoverable_agent_error(e)
      rescue StandardError, Timeout::Error, TingYun::Support::Exception::ServerConnectionException, TingYun::Support::Exception::AgentEnableException => e
        log_error(e)
        if TingYun::Agent.config[:keep_retrying]
          note_connect_failure
          ::TingYun::Agent.logger.info "Will re-attempt in 60 seconds"
          sleep 60
          retry
        else
          disconnect
        end
      rescue Exception => e
        ::TingYun::Agent.logger.error "Exception of unexpected type during Agent#connect():", e
       raise
      end


      def install_exit_handler
        TingYun::Agent.logger.debug("Installing at_exit handler")
        at_exit do
          if need_exit_code_workaround?
            exit_status = $!.status if $!.is_a?(SystemExit)
            shutdown
            exit exit_status if exit_status
          else
            shutdown
          end
        end
      end

      def need_exit_code_workaround?
        defined?(RUBY_ENGINE) && RUBY_ENGINE == "ruby" && RUBY_VERSION.match(/^1\.9/)
      end

      def initialize
        @started = false
        @environment_report = nil
        @service = TingYunService.new
        @connect_state = :pending #[:pending, :connected, :disconnected]
        @connect_attempts = 0
        @events  = TingYun::Agent::Event::EventListener.new
        @after_fork_lock = Mutex.new
        @dispatcher = TingYun::Agent::Dispatcher.new(@events)

        init_containers
      end
    end
  end
end