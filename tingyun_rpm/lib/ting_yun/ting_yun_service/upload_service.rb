# encoding: utf-8
require 'ting_yun/metrics/metric_spec'
require 'ting_yun/metrics/metric_data'

module TingYun
  class TingYunService
    module UploadService

      def metric_data(stats_hash)
        timeslice_start = stats_hash.started_at
        timeslice_end  = stats_hash.harvested_at || Time.now
        action_array = build_metric_data_array(stats_hash)
        upload_data = {
            :type => "perfMetrics",
            :timeFrom=>timeslice_start.to_i,
            :timeTo =>timeslice_end.to_i,
            :interval=> 60,
            :actions => action_array,
            :apdex => [],
            :components => [],
            :general => []
        }
        result = invoke_remote(
            :upload,
            [upload_data],
            :item_count => action_array.size
        )
        fill_metric_id_cache(result)
        result
      end

      # The collector wants to recieve metric data in a format that's different
      # from how we store it inte -nally, so this method handles the translation.
      # It also handles translating metric names to IDs using our metric ID cache.
      def build_metric_data_array(stats_hash)
        action_array = []
        stats_hash.each do |metric_spec, stats|
          # Omit empty stats as an optimization
          unless stats.is_reset?
            metric_id = metric_id_cache[metric_spec]
            metric_data = if metric_id
                            action_array <<[metric_id,[stats.call_count,stats.total_call_time,stats.total_exclusive_time,stats.max_call_time,stats.min_call_time,stats.sum_of_squares]]
                          else
                            action_array <<[{"name" =>metric_spec.name },[stats.call_count,stats.total_call_time,stats.total_exclusive_time,stats.max_call_time,stats.min_call_time,stats.sum_of_squares]]
                          end
          end
        end
        action_array
      end


      # takes an array of arrays of spec and id, adds it into the
      # metric cache so we can save the collector some work by
      # sending integers instead of strings the next time around
      def fill_metric_id_cache(pairs_of_specs_and_ids)
        pairs_of_specs_and_ids.each do |_,value|
          if value.is_a? Array
            value.each do |array|
              if array.is_a? Array
                metric_id_cache[array[0]["name"]] = array[1]
              end
            end
          end
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