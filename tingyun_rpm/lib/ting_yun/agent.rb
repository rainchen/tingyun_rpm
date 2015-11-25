# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'forwardable'
require 'ting_yun/configuration/manager'
require 'ting_yun/logger/startup_logger'

module TingYun
  module Agent
    extend self
    extend Forwardable

    @agent = nil
    @logger = nil

    @config = ::TingYun::Configuration::Manager.new

    attr_reader :config

    def agent
      return @agent if @agent
      TingYun::Agent.logger.warn("Agent unavailable as it hasn't been started.")
      TingYun::Agent.logger.warn(caller.join("\n"))
      nil
    end

    alias instance agent

    def agent=(new_instance)
      @agent = new_instance
    end


    def logger
      @logger || ::TingYun::Logger::StartupLogger.instance
    end

    def logger=(log)
      @logger = log
    end

    def init_plugin(options={})
    end

    # Install the real agent into the Agent module, and issue the start command.
    def start_agent
      TingYun::Agent.agent.start
    end

    def reset_config
      @config.reset_to_defaults
    end

  end
end