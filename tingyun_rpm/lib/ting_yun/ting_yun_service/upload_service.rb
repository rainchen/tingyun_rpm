# encoding: utf-8
require 'ting_yun/metrics/metric_spec'
require 'ting_yun/metrics/metric_data'

module TingYun
  class TingYunService
    module UploadService

      def metric_data(stats_hash)
        timeslice_start = stats_hash.started_at
        timeslice_end  = stats_hash.harvested_at || Time.now
        metric_data_array = build_metric_data_array(stats_hash)
        result = invoke_remote(
            :metric_data,
            [@agent_id, timeslice_start.to_f, timeslice_end.to_f, metric_data_array],
            :item_count => metric_data_array.size
        )
        fill_metric_id_cache(result)
        result
      end

      # The collector wants to recieve metric data in a format that's different
      # from how we store it internally, so this method handles the translation.
      # It also handles translating metric names to IDs using our metric ID cache.
      def build_metric_data_array(stats_hash)
        metric_data_array = []
        stats_hash.each do |metric_spec, stats|
          # Omit empty stats as an optimization
          unless stats.is_reset?
            metric_id = metric_id_cache[metric_spec]
            metric_data = if metric_id
                            TingYun::Metrics::MetricData.new(nil, stats, metric_id)
                          else
                            TingYun::Metrics::MetricData.new(metric_spec, stats, nil)
                          end
            metric_data_array << metric_data
          end
        end
        metric_data_array
      end


      # takes an array of arrays of spec and id, adds it into the
      # metric cache so we can save the collector some work by
      # sending integers instead of strings the next time around
      def fill_metric_id_cache(pairs_of_specs_and_ids)
        Array(pairs_of_specs_and_ids).each do |metric_spec_hash, metric_id|
          metric_spec = MetricSpec.new(metric_spec_hash['name'],
                                       metric_spec_hash['scope'])
          metric_id_cache[metric_spec] = metric_id
        end
      rescue => e
        # If we've gotten this far, we don't want this error to propagate and
        # make this post appear to have been non-successful, which would trigger
        # re-aggregation of the same metric data into the next post, so just log
        TingYun::Agent.logger.error("Failed to fill metric ID cache from response, error details follow ", e)
      end

    end
  end
end