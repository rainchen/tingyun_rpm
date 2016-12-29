# encoding: utf-8

require 'ting_yun/agent/datastore/metric_helper'
require 'ting_yun/agent/method_tracer'


module TingYun
  module Agent
    module Datastore


      def self.wrap(product, operation, collection = nil, ip_address = nil, port = nil, callback = nil )
        return yield unless operation
        metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for(product, operation, ip_address , port, nil,collection )
        TingYun::Agent::MethodTracer.trace_execution_scoped(metrics) do
          t0 = Time.now
          begin
            yield
          ensure
            elapsed_time = (Time.now - t0).to_f
            if callback
              callback.call(elapsed_time)
            end
          end
        end
      end
    end
  end
end
