# encoding: utf-8
require 'ting_yun/support/helper'
require 'ting_yun/agent'

module TingYun
  module Instrumentation
    module ThriftHelper
      def operator result_klass
        namespaces = result_klass.to_s.split('::')
        operator_name = namespaces[0].downcase
        if namespaces.last =~ /_result/
          operator_name = "#{operator_name}.#{namespaces.last.sub('_result', '').downcase}"
        end
        operator_name
      end

      def operations
        @operations ||= {}
      end

      def started_time_and_node(operate)
        _op_ = operations.delete(operate)
        time = (_op_ && _op_[:started_time]) or Time.now.to_f
        node = _op_ && _op_[:node]
        [time, node]
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
        metrics = if tingyun_host.nil?
                    ["External/thrift/#{operate}"]
                  else
                    ["External/thrift:#{tingyun_host}:#{tingyun_port}/#{operate}"]
                  end
        metrics << "External/NULL/ALL"

        if TingYun::Agent::Transaction.recording_web_transaction?
          metrics << "External/NULL/AllWeb"
        else
          metrics << "External/NULL/AllBackground"
        end
        state = TingYun::Agent::TransactionState.tl_get
        my_data = state.thrift_return_data["TingyunTxData"]
        if my_data
          uri = "thrift:#{tingyun_host}:#{tingyun_port}/#{operate}"
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


    ::Thrift::BaseProtocol.class_eval do
      def skip_with_tingyun(type)
        data = skip_without_tingyun(type)
        if data.include?("TingyunTxData")

          state = TingYun::Agent::TransactionState.tl_get
          my_data = TingYun::Support::Serialize::JSONWrapper.load data.gsub("'",'"')

          state.thrift_return_data = my_data

          transaction_sampler = ::TingYun::Agent.instance.transaction_sampler
          transaction_sampler.tl_builder.current_node[:txId] = my_data["trId"]
          transaction_sampler.tl_builder.current_node[:txData] = my_data
        end
      end
      alias :skip_without_tingyun :skip
      alias :skip  :skip_with_tingyun
    end

    ::Thrift::Client.module_eval do

      include TingYun::Instrumentation::ThriftHelper

      def send_message_args_with_tingyun(args_class, args = {})
        state = TingYun::Agent::TransactionState.tl_get
        return  unless state.execution_traced?

        cross_app_id  = TingYun::Agent.config[:tingyunIdSecret] or
            raise TingYun::Agent::CrossAppTracing::Error, "no tingyunIdSecret configured"
        txn_guid = state.request_guid
        tingyun_id = "#{cross_app_id};c=1;x=#{txn_guid}"

        data = TingYun::Support::Serialize::JSONWrapper.dump("TingyunID" => tingyun_id)
        @oprot.write_field_begin("TingyunField", 11, 6)
        @oprot.write_string(data)
        @oprot.write_field_end
        send_message_args_without_tingyun(args_class, args)
      end

      alias :send_message_args_without_tingyun :send_message_args
      alias :send_message_args  :send_message_args_with_tingyun

      def send_message_with_tingyun(name, args_class, args = {})
        tag = "#{args_class.to_s.split('::').first.downcase}.#{name}"
        t0 = Time.now.to_f
        operations[tag] = {:started_time => t0}
        state = TingYun::Agent::TransactionState.tl_get
        return  unless state.execution_traced?
        stack = state.traced_method_stack
        node = stack.push_frame(state,:thrift,t0)
        operations[tag][:node] = node

        send_message_without_tingyun(name, args_class, args)
      end

      alias :send_message_without_tingyun :send_message
      alias :send_message  :send_message_with_tingyun



      def receive_message_with_tingyun(result_klass)
        state = TingYun::Agent::TransactionState.tl_get

        t1 = Time.now.to_f

        operate = operator(result_klass)
        t0, node =  started_time_and_node(operate)
        if node
          node.name = operate
          stack = state.traced_method_stack
          stack.pop_frame(state, node, operate, t1)
        end


        result = receive_message_without_tingyun(result_klass)

        base, *other_metrics = metrics(operate)
        duration = TingYun::Helper.time_to_millis(t1 - t0)
        TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
            base, other_metrics, duration
        )
        transaction_sampler = ::TingYun::Agent.instance.transaction_sampler
        transaction_sampler.add_node_info(:uri => "thrift:#{tingyun_host}:#{tingyun_port}/#{operate}")
        result
      end

      alias :receive_message_without_tingyun :receive_message
      alias :receive_message :receive_message_with_tingyun
    end
  end

end