# encoding: utf-8
require 'ting_yun/support/helper'
require 'ting_yun/agent'
require 'ting_yun/instrumentation/support/external_error'

module TingYun
  module Instrumentation
    # some methods support the thrift client
    module ThriftHelper
      def self.operator result_klass
        namespaces = result_klass.to_s.split('::')
        "#{namespaces[0]}.#{namespaces.last.sub('_args', '').sub('_result', '')}".downcase
      end

      def operations
        @operations ||= {}
      end


      def self.started_time_and_node(operations,operate)
        _op = operations.delete(operate) || {}
        [_op[:started_time] || Time.now.to_f, _op[:node]]
      end


      def tingyun_socket
        @iprot.instance_variable_get("@trans").instance_variable_get("@transport")
      end

      def tingyun_host
        @tingyun_host ||= tingyun_socket.instance_variable_get("@host") rescue nil
      end

      def tingyun_port
        @tingyun_port  ||= tingyun_socket.instance_variable_get("@port") rescue nil
      end

      def metrics operate
        state = TingYun::Agent::TransactionState.tl_get
        metrics = unless tingyun_host
                    ["External/thrift:%2F%2F#{operate}/#{operate}","External/NULL/ALL"]
                  else
                    ["External/thrift:%2F%2F#{tingyun_host}:#{tingyun_port}%2F#{operate}/#{operate}", "External/NULL/ALL"]
                  end
        if TingYun::Agent::Transaction.recording_web_transaction?
          metrics << "External/NULL/AllWeb"
        else
          metrics << "External/NULL/AllBackground"
        end

        my_data = state.thrift_return_data

        if my_data
          uri = "thrift:%2F%2F#{tingyun_host}:#{tingyun_port}%2F#{operate}/#{operate}"
          metrics << "cross_app;#{my_data["id"]};#{my_data["action"]};#{uri}"
        end
        return metrics

      end
    end
  end
end




TingYun::Support::LibraryDetection.defer do
  named :thrift

  depends_on do
    defined?(::Thrift) && defined?(::Thrift::Client) && defined?(::Thrift::BaseProtocol)
  end


  executes do
    TingYun::Agent.logger.info 'Installing Thrift Instrumentation'
    require 'ting_yun/support/serialize/json_wrapper'
  end

  executes do
    # ::Thrift::Processor.module_eval do
    #
    #
    #
    #   def same_account?(state)
    #     server_info = TingYun::Agent.config[:tingyunIdSecret].split('|')
    #     client_info = (state.client_tingyun_id_secret || '').split('|')
    #     if !server_info[0].nil? && server_info[0] == client_info[0] && !server_info[0].empty?
    #       return true
    #     else
    #       return false
    #     end
    #   end
    #   def write_result_with_tingyun(result, oprot, name, seqid)
    #
    #     state = TingYun::Agent::TransactionState.tl_get
    #     oprot.write_message_begin(name, ::Thrift::MessageTypes::REPLY, seqid)
    #
    #     if state.execution_traced? && same_account?(state)
    #       class_name = "WebAction/thrift/#{self.class.to_s.split('::').first.downcase}.#{name}"
    #       state.current_transaction.default_name = class_name
    #       data = TingYun::Support::Serialize::JSONWrapper.dump("TingyunTxData" => build_payload(state))
    #       oprot.write_field_begin("TingyunField", 11, 6)
    #       oprot.write_string(data)
    #       oprot.write_field_end
    #       write_result_without_tingyun(result, oprot, name, seqid)
    #       state.current_transaction.add_agent_attribute(:httpStatus, 200)
    #       TingYun::Agent::Transaction.stop(state)
    #     else
    #       write_result_without_tingyun(result, oprot, name, seqid)
    #     end
    #   end
    #
    #   def write_error_with_tingyun(err, oprot, name, seqid)
    #     p 'write_error'
    #     state = TingYun::Agent::TransactionState.tl_get
    #     oprot.write_message_begin(name, ::Thrift::MessageTypes::EXCEPTION, seqid)
    #
    #     if state.execution_traced? && same_account?(state)
    #
    #       class_name = "WebAction/thrift/#{self.class.to_s.split('::').first.downcase}.#{name}"
    #       state.current_transaction.default_name = class_name
    #       data = TingYun::Support::Serialize::JSONWrapper.dump("TingyunTxData" => build_payload(state))
    #       oprot.write_field_begin("TingyunField", 11, 6)
    #       oprot.write_string(data)
    #       oprot.write_field_end
    #       write_result_without_tingyun(err, oprot, name, seqid)
    #       p 'write_error end'
    #       state.current_transaction.add_agent_attribute(:httpStatus, 500)
    #
    #       TingYun::Agent::Transaction.stop(state)
    #     else
    #       write_result_without_tingyun(err, oprot, name, seqid)
    #     end
    #   end
    #
    #
    #   def build_payload(state)
    #     state.web_duration = TingYun::Helper.time_to_millis(Time.now - state.current_transaction.start_time)
    #     payload = {
    #         :id => TingYun::Agent.config[:tingyunIdSecret].split('|')[1],
    #         :action => state.current_transaction.best_name,
    #         :trId => state.transaction_sample_builder.trace.guid,
    #         :time => {
    #             :duration => state.web_duration,
    #             :qu => state.queue_duration,
    #             :db => state.sql_duration,
    #             :ex => state.external_duration,
    #             :rds => state.rds_duration,
    #             :mc => state.mc_duration,
    #             :mon => state.mon_duration,
    #             :code => execute_duration(state)
    #         }
    #     }
    #     payload[:tr] = 1 if slow_action_tracer?(state)
    #     payload[:r] = state.client_req_id unless state.client_req_id.nil?
    #     payload
    #   end
    #
    #   def slow_action_tracer?(state)
    #     if state.web_duration > TingYun::Agent.config[:'nbs.action_tracer.action_threshold']
    #       return true
    #     else
    #       return false
    #     end
    #   end
    #
    #   def write_result_without_tingyun(result, oprot, name, seqid)
    #     result.write(oprot)
    #     oprot.write_message_end
    #     oprot.trans.flush
    #   end
    #
    #   def execute_duration(state)
    #     state.web_duration - state.queue_duration - state.sql_duration - state.external_duration - state.rds_duration - state.mc_duration - state.mon_duration
    #   end
    #
    #   alias :write_result  :write_result_with_tingyun
    #   alias :write_error  :write_error_with_tingyun
    #   # alias :write_result_without_tingyun  :write_result
    # end

    ::Thrift::BaseProtocol.class_eval do

      def skip_with_tingyun(type)

        data = skip_without_tingyun(type)
        state = TingYun::Agent::TransactionState.tl_get
        if data.is_a? ::String
          if data.include?("TingyunTxData")

            my_data = TingYun::Support::Serialize::JSONWrapper.load data.gsub("'",'"')

            state.thrift_return_data = my_data["TingyunTxData"]

            transaction_sampler = ::TingYun::Agent.instance.transaction_sampler
            transaction_sampler.tl_builder.current_node[:txId] = state.request_guid
            transaction_sampler.tl_builder.current_node[:txData] = my_data["TingyunTxData"]
          # elsif data.include?("TingyunID")
          #   TingYun::Agent::Transaction.start(state, :thrift, :apdex_start_time => Time.now)
          #   my_data = TingYun::Support::Serialize::JSONWrapper.load data.gsub("'",'"')
          #   save_referring_transaction_info(state, my_data)
          end
        end
      end

      # def save_referring_transaction_info(state,data)
      #
      #   info = data["TingyunID"].split(';')
      #   tingyun_id_secret = info[0]
      #   client_transaction_id = info.find do |e|
      #     e.match(/x=/)
      #   end.split('=')[1] rescue nil
      #   client_req_id = info.find do |e|
      #     e.match(/r=/)
      #   end.split('=')[1] rescue nil
      #
      #   state.client_tingyun_id_secret = tingyun_id_secret
      #   state.client_transaction_id = client_transaction_id
      #   state.client_req_id = client_req_id
      # end

      alias :skip_without_tingyun :skip
      alias :skip  :skip_with_tingyun
    end

    ::Thrift::Client.module_eval do

      include TingYun::Instrumentation::ThriftHelper

        def send_message_args_with_tingyun(args_class, args = {})
          state = TingYun::Agent::TransactionState.tl_get
          return  unless state.execution_traced?
          data = TingYun::Support::Serialize::JSONWrapper.dump(
              "TingyunID" => "#{TingYun::Agent.config[:tingyunIdSecret] };c=1;x=#{state.request_guid}"
          )
          @oprot.write_field_begin("TingyunField", 11, 6)
          @oprot.write_string(data)
          @oprot.write_field_end
          send_message_args_without_tingyun(args_class, args)
        end

        alias :send_message_args_without_tingyun :send_message_args
        alias :send_message_args  :send_message_args_with_tingyun


      def send_message_with_tingyun(name, args_class, args = {})
        state = TingYun::Agent::TransactionState.tl_get
        return  unless state.execution_traced?
        _t = Time.now.to_f
        operations["#{args_class.to_s.split('::').first}.#{name}".downcase] =
            {:started_time => _t, :node => state.traced_method_stack.push_frame(state,:thrift, _t)}

        send_message_without_tingyun(name, args_class, args)
      end

      alias :send_message_without_tingyun :send_message
      alias :send_message  :send_message_with_tingyun

      def send_oneway_message_with_tingyun(name, args_class, args = {})
        tag = "#{args_class.to_s.split('::').first}.#{name}".downcase
        op_started = Time.now.to_f
        base, *other_metrics = metrics(tag)
        result = send_oneway_message_without_tingyun(name, args_class, args)
        duration = (Time.now.to_f - op_started)*1000
        TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(base, other_metrics, duration)
        result
      end
      alias :send_oneway_message_without_tingyun :send_oneway_message
      alias :send_oneway_message :send_oneway_message_with_tingyun

      def receive_message_with_tingyun(result_klass)
        operate = TingYun::Instrumentation::ThriftHelper.operator(result_klass)

        _t, node = TingYun::Instrumentation::ThriftHelper.started_time_and_node(operations, operate)

        result = receive_message_without_tingyun(result_klass)
        node_name, *other_metrics = metrics(operate)
        unless result && result.success
          err = ::Thrift::ApplicationException.new(::Thrift::ApplicationException::MISSING_RESULT, "#{operate} failed: unknown result")
          ::TingYun::Instrumentation::Support::ExternalError.handle_error(err, node_name)
        end

        t_ = Time.now.to_f
        duration = TingYun::Helper.time_to_millis(t_ - _t)
        TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
            other_metrics.pop, other_metrics, duration
        )
        if node
          state = TingYun::Agent::TransactionState.tl_get
          node.name = node_name
          ::TingYun::Agent.instance.transaction_sampler.add_node_info(:uri => "thrift:#{tingyun_host}:#{tingyun_port}/#{operate}")
          stack = state.traced_method_stack
          stack.pop_frame(state, node, node_name, t_)
        end

        result
      end

      alias :receive_message_without_tingyun :receive_message
      alias :receive_message :receive_message_with_tingyun
    end
  end

end