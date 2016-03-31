# encoding: utf-8
require 'ting_yun/metrics/metric_spec'
require 'ting_yun/metrics/metric_data'
require 'ting_yun/support/serialize/encodes'

module TingYun
  class TingYunService
    module UploadService

      def compressed_json
        TingYun::Support::Serialize::Encoders::CompressedJSON
      end

      def base64_compressed_json
        TingYun::Support::Serialize::Encoders::Base64CompressedJSON
      end

      def json
        TingYun::Support::Serialize::Encoders::Json
      end

      def metric_data(stats_hash)

        timeslice_start = stats_hash.started_at
        timeslice_end = stats_hash.harvested_at || Time.now

        action_array, adpex_array, general_array, components_array, errors_array = build_metric_data_array(stats_hash)

        upload_data = {
            :type => 'perfMetrics',
            :timeFrom => timeslice_start.to_i,
            :timeTo => timeslice_end.to_i,
            :interval => 60,
            :actions => action_array,
            :apdex => adpex_array,
            :components => components_array,
            :general => general_array,
            :errors  => errors_array
        }

        result = invoke_remote(:upload,[upload_data])
        fill_metric_id_cache(result)
        result
      end

      # The collector wants to recieve metric data in a format that's different
      # from how we store it inte -nally, so this method handles the translation.
      # It also handles translating metric names to IDs using our metric ID cache.
      def build_metric_data_array(stats_hash)
        action_array = []
        adpex_array = []
        general_array = []
        components_array = []
        errors_array = []
        stats_hash.each do |metric_spec, stats|

          # Omit empty stats as an optimization
          unless stats.is_reset?
            metric_id = metric_id_cache[metric_spec.name]

            if metric_spec.name.start_with?('WebAction')
              action_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('Apdex')
              adpex_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('Database') && !metric_spec.scope.empty?
              components_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('Database') && metric_spec.scope.empty?
              general_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('Errors') && metric_spec.scope.empty?
              errors_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('MongoDB','Redis','Memcached') && !metric_spec.scope.empty?
              components_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('MongoDB','Redis','Memcached') && metric_spec.scope.empty?
              general_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
            elsif metric_spec.name.start_with?('External')
              if metric_spec.scope.empty?
                general_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
              else
                components_array << TingYun::Metrics::MetricData.new(metric_spec, stats, metric_id)
              end
            end
          end
        end

        [action_array, adpex_array, general_array, components_array, errors_array]
      end


      # takes an array of arrays of spec and id, adds it into the
      # metric cache so we can save the collector some work by
      # sending integers instead of strings the next time around
      def fill_metric_id_cache(pairs_of_specs_and_ids)
        pairs_of_specs_and_ids.each do |_, value|
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

    def error_data(unsent_errors)
      upload_data = {
          :type => 'errorTraceData',
          :errors => unsent_errors
      }
      invoke_remote(:upload, [upload_data])
    end

    def action_trace_data(traces)
      upload_data = {
          :type => 'actionTraceData',
          :actionTraces => traces
      }
      invoke_remote(:upload, [upload_data], :encoder=> json)
    end

    def sql_trace(sql_trace)
      upload_data = {
          :type => 'sqlTraceData',
          :sqlTraces => sql_trace
      }

      invoke_remote(:upload, [upload_data], :encoder=> json )

    end
  end
end