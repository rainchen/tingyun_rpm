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
