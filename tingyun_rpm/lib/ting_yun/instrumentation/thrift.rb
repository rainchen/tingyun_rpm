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

      def started_time(operate)
        _op_ = operations.delete(operate)
        (_op_ && _op_[:started_time]) or Time.now.to_f
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
      end
    end
  end
end




TingYun::Support::LibraryDetection.defer do
  named :thrift

  depends_on do
    defined?(::Thrift) && defined?(::Thrift::Client)
  end


  executes do
    TingYun::Agent.logger.info 'Installing Thrift Instrumentation'
  end

  executes do
    ::Thrift::Client.module_eval do
      include TingYun::Instrumentation::ThriftHelper

      def send_message_with_tingyun(name, args_class, args = {})
        operations[name] = {:started_time => Time.now.to_f}
        send_message_without_tingyun(name, args_class, args = {})
      end
      alias :send_message_without_tingyun :send_message
      alias :send_message  :send_message_with_tingyun

      def receive_message_with_tingyun(result_klass)
        operate = operator(result_klass)
        operate_started_time =  started_time(operate)
        base, *other_metrics = metrics(operate)
        result = receive_message_without_tingyun(result_klass)
        duration = TingYun::Helper.time_to_millis(Time.now.to_f - operate_started_time)
        TingYun::Agent.instance.stats_engine.tl_record_scoped_and_unscoped_metrics(
            base, other_metrics, duration
        )
        result
      end

      alias :receive_message_without_tingyun :receive_message
      alias :receive_message :receive_message_with_tingyun
    end
  end

end