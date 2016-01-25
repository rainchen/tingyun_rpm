# encoding: utf-8

require 'ting_yun/agent/datastore/metric_helper'
require 'ting_yun/agent/method_tracer'


module TingYun
  module Agent
    module Datastore


      def self.wrap(product, operation, collection = nil)
        return yield unless operation

        metrics = TingYun::Agent::Datastore::MetricHelper.metrics_for(product, operation, collection)

        TingYun::Agent::MethodTracer.trace_execution_scoped(metrics) do
          yield
        end
      end
    end
  end
end
