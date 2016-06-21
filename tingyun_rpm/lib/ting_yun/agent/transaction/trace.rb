  # encoding: utf-8
require 'ting_yun/agent/transaction/trace_node'
require 'ting_yun/support/helper'
require 'ting_yun/support/coerce'
require 'ting_yun/agent/database'
module TingYun
  module Agent
    class Transaction
      class Trace

        attr_accessor :node_count, :threshold, :metric_name, :uri, :guid, :attributes, :start_time, :finished, :tx_id

        attr_reader  :root_node

        def initialize(start_time)
          @start_time = start_time
          @node_count = 0
          @root_node = TingYun::Agent::Transaction::TraceNode.new(0.0, 'ROOT')
          @prepared = false
          @guid = generate_guid
        end

        def create_node(time_since_start, metric_name = nil)
          @node_count += 1
          TingYun::Agent::Transaction::TraceNode.new(time_since_start, metric_name)
        end

        def duration
          @root_node.duration
        end



        include TingYun::Support::Coerce
        
        def trace_tree
          [
              duration,
              request_params,
              custom_params,
              @root_node.to_array
          ]
        end

        def to_collector_array(encoder)
          [
              @start_time.round,
              duration,
              TingYun::Helper.correctly_encoded(metric_name),
              TingYun::Helper.correctly_encoded(uri),
              encoder.encode(trace_tree),
              tx_id || '',
              guid
          ]
        end

        def prepare_to_send!
          return self if @prepared

          if TingYun::Agent::Database.should_record_sql?('nbs.action_tracer.record_sql')
            collect_explain_plans!
            prepare_sql_for_transmission!
          else
            @root_node.each_call do |node|
              node.params.delete(:sql)
            end
          end
          @prepared = true
          self
        end

        def collect_explain_plans!
          return unless TingYun::Agent::Database.should_action_collect_explain_plans?
          threshold = TingYun::Agent.config[:'nbs.action_tracer.action_threshold']
          @root_node.each_call do |node|
            if node[:sql] && node.duration > threshold
              node[:explainPlan] = node.explain_sql
            end
          end
        end

        def prepare_sql_for_transmission!(&block)
          strategy = TingYun::Agent::Database.record_sql_method('nbs.action_tracer.record_sql')
          @root_node.each_call do |node|
            next unless node[:sql]

            case strategy
              when :obfuscated
                node[:sql] = TingYun::Agent::Database.obfuscate_sql(node[:sql])
              when :raw
                node[:sql] = node[:sql].sql.to_s
              else
                node[:sql] = nil
            end
          end
        end

        def custom_params
          {
              :threadName => string(attributes.agent_attributes[:threadName]),
              :httpStatus => int(attributes.agent_attributes[:httpStatus]),
              :referer    => string(attributes.agent_attributes[:referer]) || ''
          }
        end

        def request_params
          attributes.agent_attributes[:request_params]
        end

        HEX_DIGITS = (0..15).map{|i| i.to_s(16)}
        GUID_LENGTH = 16

        # generate a random 64 bit uuid
        private
        def generate_guid
          guid = ''
          GUID_LENGTH.times do
            guid << HEX_DIGITS[rand(16)]
          end
          guid
        end
      end
    end
  end
end