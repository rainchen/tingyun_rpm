# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))

require 'ting_yun/agent/container_data_manager'
require 'ting_yun/ting_yun_service'

module TingYun
  module Agent
    class ContainerDataManagerTest < MiniTest::Test
      def setup
        @agent = TingYun::Agent::Agent.instance
        @agent.service = default_service
      end

      def test_transmit_data_should_transmit
        @agent.service.expects(:metric_data).at_least_once
        @agent.stats_engine.record_scoped_and_unscoped_metrics(['foo'], 12)
        @agent.transmit_data
      end

      def default_service(stubbed_method_overrides = {})
        service = stub
        stubbed_method_defaults = {
            :connect => {},
            :collector => stub_everything,
            :request_timeout= =>  nil,
            :metric_data => nil,
        }

        service.stubs(stubbed_method_defaults.merge(stubbed_method_overrides))

        # When session gets called yield to the given block.
        service.stubs(:session).yields
        service
      end


    end
  end
end
