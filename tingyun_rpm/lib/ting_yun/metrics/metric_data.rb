# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'ting_yun/support/coerce'

module TingYun
  module Metrics
    class MetricData

      # nil, or a TingYun::Metrics::MetricSpec object if we have no cached ID
      attr_reader :metric_spec
      # nil or a cached integer ID for the metric from the collector.
      attr_accessor :metric_id
      # the actual statistics object
      attr_accessor :stats

      def initialize(metric_spec, stats, metric_id)
        @metric_spec = metric_spec
        self.stats = stats
        self.metric_id = metric_id
      end

      def eql?(o)
        (metric_spec.eql? o.metric_spec) && (stats.eql? o.stats)
      end

      def hash
        metric_spec.hash ^ stats.hash
      end

      # Serialize with all attributes, but if the metric id is not nil, then don't send the metric spec
      def to_json(*a)
        %Q[{"metric_spec":#{metric_id ? 'null' : metric_spec.to_json},"stats":{"total_exclusive_time":#{stats.total_exclusive_time},"min_call_time":#{stats.min_call_time},"call_count":#{stats.call_count},"sum_of_squares":#{stats.sum_of_squares},"total_call_time":#{stats.total_call_time},"max_call_time":#{stats.max_call_time}},"metric_id":#{metric_id ? metric_id : 'null'}}]
      end

      def to_s
        if metric_spec
          "#{metric_spec.name}(#{metric_spec.scope}): #{stats}"
        else
          "#{metric_id}: #{stats}"
        end
      end

      def inspect
        "#<MetricData metric_spec:#{metric_spec.inspect}, stats:#{stats.inspect}, metric_id:#{metric_id.inspect}>"
      end

      include TingYun::Support::Coerce

      def to_collector_array(encoder=nil)
        stat_key = metric_id || stats_has_parent?
        [ stat_key,metrics(stat_key)]
      end

      def stats_has_parent?
        hash =  { 'name' => metric_spec.name }
        hash['calleeId'] = metric_spec.calleeId unless metric_spec.calleeId.nil?
        hash['calleeName'] = metric_spec.calleeName unless metric_spec.calleeName.nil?
        unless metric_spec.scope.empty?
          hash['parent'] = metric_spec.scope
        end

        return hash
      end

      def metrics(stat_key)

        metrics = []

        metrics << int(stats.call_count, stat_key)
        if stats.min_call_time != 0.0 #apedx
          metrics << float(stats.total_call_time, stat_key)
          metrics << float(stats.total_exclusive_time, stat_key)
          metrics << float(stats.min_call_time, stat_key)
        end

        if stats.max_call_time !=0.0 #
          metrics << float(stats.max_call_time, stat_key)
          metrics << float(stats.sum_of_squares, stat_key)
        end

        metrics
      end
    end
  end
end