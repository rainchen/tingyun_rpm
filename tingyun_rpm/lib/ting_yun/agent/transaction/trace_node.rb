# encoding: utf-8
require 'ting_yun/support/helper'
require 'ting_yun/support/coerce'

module TingYun
  module Agent
    class Transaction
      class TraceNode

        attr_reader :entry_timestamp, :parent_node, :called_nodes
        attr_accessor :metric_name, :exit_timestamp



        UNKNOWN_NODE_NAME = '<unknown>'.freeze


        def initialize(timestamp, metric_name)
          @entry_timestamp = timestamp
          @metric_name     = metric_name || UNKNOWN_NODE_NAME
          @called_nodes    = nil
        end

        def add_called_node(s)
          @called_nodes ||= []
          @called_nodes << s
          s.parent_node = self
        end

        def end_trace(timestamp)
          @exit_timestamp = timestamp
        end

        # return the total duration of this node
        def duration
          (@exit_timestamp - @entry_timestamp).to_f
        end


        def to_array
          [TingYun::Helper.time_to_millis(entry_timestamp),
           TingYun::Helper.time_to_millis(exit_timestamp),
           TingYun::Support::Coerce.string(metric_name),
           (@params || {})] +
          [ (@called_nodes ? @called_nodes.map{|s| s.to_array} : []) ]
        end

        def params
          @params ||= {}
        end

        def params=(p)
          @params = p
        end

      end
    end
  end
end
