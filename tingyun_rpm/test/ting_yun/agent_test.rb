# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','test_helper'))

require 'ting_yun/logger/startup_logger'
require 'ting_yun/agent'


module TingYun
  class AgentTest < Minitest::Test

  	def setup

  	end

  	def teardown
    end

    def test_config
      ::TingYun::Agent.config.must_be_instance_of ::TingYun::Configuration::Manager
    end
    def test_logger_is_singleton_instance
      @logger = ::TingYun::Logger::StartupLogger.instance
      assert_equal @logger, ::TingYun::Agent.logger
      ::TingYun::Agent.logger.must_be_instance_of ::TingYun::Logger::StartupLogger
    end
  end
end