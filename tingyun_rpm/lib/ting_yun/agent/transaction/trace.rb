# encoding: utf-8
require 'ting_yun/agent/transaction/trace_node'
require 'ting_yun/support/helper'
require 'ting_yun/support/coerce'
module TingYun
  module Agent
    class Transaction
      class Trace

        attr_accessor :node_count, :threshold, :metric_name, :uri, :guid, :attributes, :start_time, :finished

        attr_reader  :root_node

        def initialize(start_time)
          @start_time = start_time
          @node_count = 0
          @root_node = TingYun::Agent::Transaction::TraceNode.new(0.0, "ROOT")
          @prepared = false
        end

        def create_node(time_since_start, metric_name = nil)
          @node_count += 1
          TingYun::Agent::Transaction::TraceNode.new(time_since_start, metric_name)
        end

        def duration
          (self.root_node.duration * 1000).round
        end

        include TingYun::Support::Coerce

        def action_trace_data
          [
              @start_time,
          ]
        end

        def to_collector_array(encoder)
          [
              @start_time.round,
              TingYun::Helper.time_to_millis(duration),
              TingYun::Helper.correctly_encoded(metric_name),
              TingYun::Helper.correctly_encoded(uri),
              action_trace_data



          ]
        end

        def prepare_to_send!
          return self if @prepared

          @prepared = true
          self
        end
      end
    end
  end
end
