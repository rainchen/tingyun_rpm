# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','test_helper'))

require 'ting_yun/logger/startup_logger'
require 'ting_yun/agent'
require 'ting_yun/agent/agent'


module TingYun
  class AgentTest < Minitest::Test

    include TingYun::Agent
    def setup
      @agent = TingYun::Agent
      @agent.agent  = TingYun::Agent::Agent.instance
    end

    def teardown
      @agent.agent.drop_buffered_data
    end

    def test_reset_config
       with_config(:test => "test") do
         assert_equal "test", @agent.config[:test]
       end
       @agent.reset_config

       assert_nil @agent.config[:test]
    end

    def test_record_metric_with_number
      @agent.record_metric("custom/number/test",1);
      stats = @agent.agent.stats_engine.instance_variable_get(:@stats_hash)["custom/number/test"]
      assert stats
      assert_equal 1, stats.call_count
      assert_equal 1, stats.total_call_time
      assert_equal 1, stats.min_call_time
      assert_equal 1, stats.max_call_time
      assert_equal 1, stats.total_exclusive_time
      assert_equal 1, stats.sum_of_squares

      @agent.record_metric("custom/number/test",3);
      stats = @agent.agent.stats_engine.instance_variable_get(:@stats_hash)["custom/number/test"]
      assert_equal 2, stats.call_count
      assert_equal 4, stats.total_call_time
      assert_equal 1, stats.min_call_time
      assert_equal 3, stats.max_call_time
      assert_equal 4, stats.total_exclusive_time
      assert_equal 10, stats.sum_of_squares

      @agent.record_metric("custom/number/test2",1);
      stats = @agent.agent.stats_engine.instance_variable_get(:@stats_hash)["custom/number/test2"]
      assert stats
      assert_equal 1, stats.call_count
      assert_equal 1, stats.total_call_time
      assert_equal 1, stats.min_call_time
      assert_equal 1, stats.max_call_time
      assert_equal 1, stats.total_exclusive_time
      assert_equal 1, stats.sum_of_squares
    end

    def test_record_metric_with_hash
      @agent.record_metric("custom/hash/test",count: 2, total: 4, min: 1, max: 3, sum_of_squares: 10);
      stats = @agent.agent.stats_engine.instance_variable_get(:@stats_hash)["custom/hash/test"]
      assert stats
      assert_equal 2, stats.call_count
      assert_equal 4, stats.total_call_time
      assert_equal 1, stats.min_call_time
      assert_equal 3, stats.max_call_time
      assert_equal 4, stats.total_exclusive_time
      assert_equal 10, stats.sum_of_squares
    end

    def test_manual_start_default
      mocked_framework

      TingYun::Frameworks.expects(:init_start).with({:'nbs.agent_enabled' => true, :sync_startup => true})
      TingYun::Agent.manual_start
    end

    def test_manual_start_with_opts
      TingYun::Frameworks.expects(:init_start).with({:'nbs.agent_enabled' => true, :sync_startup => false})
      TingYun::Agent.manual_start(:sync_startup => false)
    end


    private

     def mocked_framework
       server = TingYun::Support::Collector.new('localhost', 3000)
       framework = OpenStruct.new(:license_key => 'abcdef',
                                :server => server)
       framework.instance_eval do
         def [](key)
           nil
         end

         def fetch(k,d)
           nil
         end
       end
       TingYun::Frameworks::Framework.stubs(:instance).returns(framework)
       framework
     end
  end
end