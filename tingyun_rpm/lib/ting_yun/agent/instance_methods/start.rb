# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


# before the real start,do check and log things
module TingYun
  module Agent
    module InstanceMethods
      module Start

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

        def started?
          @started
        end

        # Check whether we have already started, which is an error condition
        def already_started?
          if started?
            Agent.logger.info("Agent Started Already!")
            true
          end
        end

        # The agent is disabled when it is not force enabled by the
        # 'agent_enabled' option (e.g. in a manual start), or
        # enabled normally through the configuration file
        def disabled?
          !Agent.config[:agent_enabled]
        end

        def log_the_startup
          log_the_environment
          log_the_dispatcher
          log_the_app_name
        end

        def log_the_environment

        end

        # Logs the dispatcher to the log file to assist with
        # debugging. When no debugger is present, logs this fact to
        # assist with proper dispatcher detection
        def log_the_dispatcher
          dispatcher_name = Agent.config[:dispatcher].to_s

          if dispatcher_name.empty?
            Agent.logger.info 'No known dispatcher detected.'
          else
            Agent.logger.info "Dispatcher: #{dispatcher_name}"
          end
        end

        def log_the_app_name
          Agent.logger.info "Application: #{Agent.config.app_names.join(", ")}"
        end

        def is_sinatra_app?
          (
          defined?(Sinatra::Application) &&
              Sinatra::Application.respond_to?(:run) &&
              Sinatra::Application.run?
          )
        end

        # Classy logging of the agent version and the current pid,
        # so we can disambiguate processes in the log file and make
        # sure they're running a reasonable version
        def log_version_and_pid
          Agent.logger.debug "Ting Yun Ruby Agent #{TingYun::VERSION::STRING} Initialized: pid = #{$$}"
        end

        # Warn the user if they have configured their agent not to
        # send data, that way we can see this clearly in the log file
        def is_monitoring?
          if Agent.config[:monitor_mode]
            true
          else
            Agent.logger.warn('Agent configured not to send data in this environment.')
            false
          end
        end

        # Tell the user when the license key is missing so they can
        # fix it by adding it to the file
        def has_license_key?
          if Agent.config[:license_key] && Agent.config[:license_key].length > 0
            true
          else
            Agent.logger.warn("No license key found. " +
                                  "This often means your tingyun.yml file was not found, or it lacks a section for the running environment. You may also want to try linting your tingyun.yml to ensure it is valid YML.")
            false
          end
        end

        # A license key is an arbitrary 40 character string,
        # usually looks something like a SHA1 hash
        def correct_license_length
          key = Agent.config[:license_key]

          if key.length == 40
            true
          else
            Agent.logger.error("Invalid license key: #{key}")
            false
          end
        end

        # A correct license key exists and is of the proper length
        def has_correct_license_key?
          has_license_key? && correct_license_length
        end

        # Logs the configured application names
        def app_name_configured?
          names = Agent.config.app_names
          return names.respond_to?(:any?) && names.any?
        end


        # If we're using a dispatcher that forks before serving
        # requests, we need to wait until the children are forked
        # before connecting, otherwise the parent process sends useless data
        def is_using_forking_dispatcher?
          if [:puma, :passenger, :rainbows, :unicorn].include? Agent.config[:dispatcher]
            Agent.logger.info "Deferring startup of agent reporting thread because #{Agent.config[:dispatcher]} may fork."
            true
          else
            false
          end
        end

        # Sanity-check the agent configuration and start the agent,
        # setting up the worker thread and the exit handler to shut
        # down the agent
        def check_config_and_start_the_agent
          return unless is_monitoring? && has_correct_license_key?
          return if is_using_forking_dispatcher?
          setup_and_start_the_agent
        end

        # This is the shared method between the main agent startup and the
        # after_fork call restarting the thread in deferred dispatchers.
        #
        # Treatment of @started and env report is important to get right.
        def setup_and_start_the_agent(options={})
          @started = true
          start_worker_thread(options)
        end
      end
    end
  end
end