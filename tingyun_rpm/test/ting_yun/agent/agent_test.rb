# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require "ting_yun/agent/agent"
require "ting_yun/configuration/manager"
require 'ting_yun/agent/class_methods'

module TingYun
  module Agent
    class AgentTest < MiniTest::Test
      def setup
      end

      def teardown

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

      def test_can_not_call_new
       p ::TingYun::Agent::Agent.new
      end


    end
  end
end