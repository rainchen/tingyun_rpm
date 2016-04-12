# encoding: utf-8

require 'ting_yun/agent/datastore/metric_helper'
require 'ting_yun/agent/method_tracer'


module TingYun
  module Agent
    module Datastore


      def self.wrap(product, operation, collection = nil, callback = nil)
        return yield unless operation

        metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for(product, operation, collection)

        scoped_metric = metrics.last

        TingYun::Agent::MethodTracer.trace_execution_scoped(metrics) do
          t0 = Time.now
          begin
            result = yield
          ensure
            elapsed_time = (Time.now - t0).to_f
            if callback
              callback.call(result, scoped_metric, elapsed_time)
            end
          end
        end
      end
    end
  end
end
