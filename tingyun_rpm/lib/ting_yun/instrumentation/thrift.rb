# encoding: utf-8
require 'ting_yun/support/helper'
require 'ting_yun/agent'
require 'ting_yun/instrumentation/support/external_error'

module TingYun
  module Instrumentation
    module ThriftHelper
      def operator result_klass
        namespaces = result_klass.to_s.split('::')
        operator_name = namespaces[0].downcase
        if namespaces.last =~ /_result/
          operator_name = "#{operator_name}.#{namespaces.last.sub('_result', '').downcase}"
        elsif namespaces.last =~ /_args/
          operator_name = "#{operator_name}.#{namespaces.last.sub('_args', '').downcase}"
        end

        operator_name
      end

      def operations
        @operations ||= {}
      end

      def started_time_and_node(operate)
        _op_ = operations.delete(operate)
        time = (_op_ && _op_[:started_time]) || Time.now.to_f
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
        state = TingYun::Agent::TransactionState.tl_get
        metrics = if tingyun_host.nil?
                    ["External/thrift:%2F%2F#{operate}/#{operate}"]
                  else
                    ["External/thrift:%2F%2F#{tingyun_host}:#{tingyun_port}%2F#{operate}/#{operate}"]
                  end
        metrics << "External/NULL/ALL"

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
          end
        end
      end

      def save_referring_transaction_info(state,data)

        info = data["TingyunID"].split(';')
        tingyun_id_secret = info[0]
        client_transaction_id = info.find do |e|
          e.match(/x=/)
        end.split('=')[1] rescue nil
        client_req_id = info.find do |e|
          e.match(/r=/)
        end.split('=')[1] rescue nil

        state.client_tingyun_id_secret = tingyun_id_secret
        state.client_transaction_id = client_transaction_id
        state.client_req_id = client_req_id
        state.transaction_sample_builder.trace.tx_id = client_transaction_id

      end

      alias :skip_without_tingyun :skip
      alias :skip  :skip_with_tingyun
    end

    ::Thrift::Client.module_eval do

      include TingYun::Instrumentation::ThriftHelper


        def send_message_args_with_tingyun(args_class, args = {})
          begin
            state = TingYun::Agent::TransactionState.tl_get
            return  unless state.execution_traced?
            cross_app_id  = TingYun::Agent.config[:tingyunIdSecret] or
                raise TingYun::Agent::CrossAppTracing::Error, "no tingyunIdSecret configured"
            txn_guid = state.request_guid
            tingyun_id = "#{cross_app_id};c=1;x=#{txn_guid}"
            state.transaction_sample_builder.trace.tx_id = txn_guid

            data = TingYun::Support::Serialize::JSONWrapper.dump("TingyunID" => tingyun_id)
            @oprot.write_field_begin("TingyunField", 11, 6)
            @oprot.write_string(data)
            @oprot.write_field_end
          rescue => e
            TingYun::Agent.logger.error("Failed to thrift send_message_args_with_tingyun : ", e)
          ensure
            send_message_args_without_tingyun(args_class, args)
          end
        end

        alias :send_message_args_without_tingyun :send_message_args
        alias :send_message_args  :send_message_args_with_tingyun


      def send_message_with_tingyun(name, args_class, args = {})

        begin
          tag = "#{args_class.to_s.split('::').first}.#{name}".downcase
          t0 = Time.now.to_f
          operations[tag] = {:started_time => t0}
          state = TingYun::Agent::TransactionState.tl_get
          return  unless state.execution_traced?
          stack = state.traced_method_stack
          node = stack.push_frame(state,:thrift,t0)
          operations[tag][:node] = node
        rescue => e
          TingYun::Agent.logger.error("Failed to thrift send_message_with_tingyun : ", e)
        ensure
          send_message_without_tingyun(name, args_class, args)
        end

      end

      alias :send_message_without_tingyun :send_message
      alias :send_message  :send_message_with_tingyun

      def send_oneway_message_with_tingyun(name, args_class, args = {})

        begin
          tag = "#{args_class.to_s.split('::').first}.#{name}".downcase
          op_started = Time.now.to_f
          base, *other_metrics = metrics(tag)
          result = send_oneway_message_without_tingyun(name, args_class, args)
          duration = (Time.now.to_f - op_started)*1000
          TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(base, other_metrics, duration)
          result
        rescue => e
          TingYun::Agent.logger.error("Failed to thrift send_oneway_message_with_tingyun : ", e)
          return send_oneway_message_without_tingyun(name, args_class, args)
        end

      end
      alias :send_oneway_message_without_tingyun :send_oneway_message
      alias :send_oneway_message :send_oneway_message_with_tingyun

      def receive_message_with_tingyun(result_klass)
        begin
          state = TingYun::Agent::TransactionState.tl_get

          operate = operator(result_klass)

          t0, node =  started_time_and_node(operate)


          result = receive_message_without_tingyun(result_klass)
          if result.nil? || result.success.nil?
            e = ::Thrift::ApplicationException.new(::Thrift::ApplicationException::MISSING_RESULT, "#{operate} failed: unknown result")
            ::TingYun::Instrumentation::Support::ExternalError.handle_error(e,metrics(operate)[0])
          end

          t1 = Time.now.to_f
          node_name, *other_metrics = metrics(operate)
          duration = TingYun::Helper.time_to_millis(t1 - t0)

          TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
              other_metrics.pop, other_metrics, duration
          )
          if node
            node.name = node_name
            transaction_sampler = ::TingYun::Agent.instance.transaction_sampler
            transaction_sampler.add_node_info(:uri => "thrift:#{tingyun_host}:#{tingyun_port}/#{operate}")
            stack = state.traced_method_stack
            stack.pop_frame(state, node, node_name, t1)
          end

          result
        rescue => e
          TingYun::Agent.logger.error("Failed to thrift receive_message_with_tingyun : ", e)
          return  receive_message_without_tingyun(result_klass)
        end
      end

      alias :receive_message_without_tingyun :receive_message
      alias :receive_message :receive_message_with_tingyun
    end
  end

end