# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require "ting_yun/agent/agent"
require "ting_yun/configuration/manager"
require 'ting_yun/agent/class_methods'
require 'ting_yun/support/collector'
require 'ting_yun/environment_report'

module TingYun
  module Agent
    class AgentTest < MiniTest::Test
      def setup
         @agent = TingYun::Agent::Agent.instance
      end

      def teardown
        TingYun::Agent.config.reset_to_defaults
      end

      def test_class_methods
        [:config,:logger,:instance].each do |method|
          ::TingYun::Agent::Agent.must_respond_to(method)
        end
      end

      def test_agent_should_singleton
        agent1 = ::TingYun::Agent::Agent.instance
        agent2 = ::TingYun::Agent::Agent.instance
        assert_equal agent1, agent2
      end

      # def test_env
      #   with_config(:ssl=> false) do
      #     collector = TingYun::Support::Collector.new('redirect.networkbench.com', 80)
      #     @agent.service = TingYun::TingYunService.new('888-888-888',collector)
      #     @agent.generate_environment_report
      #     @agent.connect_to_server
      #
      #   end
      # end

    end
  end
end