# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper'))
require 'ting_yun/agent/collector/stats_engine'

module TingYun::Agent::Collector
  class StatsEngineTest <  MiniTest::Test
    def setup
      @engine = TingYun::Agent::Collector::StatsEngine.new
    end

    def test_respond
    end

  end
end