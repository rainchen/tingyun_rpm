# encoding: utf-8

require 'ting_yun/agent/collector/stats_engine/stats_hash'
require 'ting_yun/agent/collector/stats_engine/metric_stats'

module TingYun
  module Agent
    module Collector
      # This class handles all the statistics gathering for the agent
      class StatsEngine

        include MetricStats


        def initialize
          @stats_lock = Mutex.new
          @stats_hash = StatsHash.new
        end

        # All access to the @stats_hash ivar should be funnelled through this
        # method to ensure thread-safety.
        def with_stats_lock
          @stats_lock.synchronize { yield }
        end
      end
    end
  end
end
