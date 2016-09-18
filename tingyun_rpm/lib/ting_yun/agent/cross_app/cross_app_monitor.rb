# encoding: utf-8
require 'ting_yun/agent/cross_app/inbound_request_monitor'
require 'ting_yun/agent/cross_app/cross_app_tracing'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent'
require 'ting_yun/support/serialize/json_wrapper'


module TingYun
  module Agent
    class CrossAppMonitor < TingYun::Agent::InboundRequestMonitor


      TY_ID_HEADER = 'HTTP_X_TINGYUN_ID'.freeze
      TY_DATA_HEADER = 'X-Tingyun-Tx-Data'.freeze


      def on_finished_configuring(events)
        register_event_listeners(events)
      end

      # Expected sequence of events:
      #   :before_call will save our cross application request id to the thread
      #   :after_call will write our response headers/metrics and clean up the thread
      def register_event_listeners(events)
        TingYun::Agent.logger.debug("Wiring up Cross Application Tracing to events after finished configuring")
        state = TingYun::Agent::TransactionState.tl_get

        events.subscribe(:cross_app_before_call) do |env| #THREAD_LOCAL_ACCESS
          if cross_app_enabled?
            save_referring_transaction_info(state, env)  unless env[TY_ID_HEADER].nil?
          end
        end

        events.subscribe(:cross_app_after_call) do |_status_code, headers, _body| #THREAD_LOCAL_ACCESS
          insert_response_header(state, headers)
        end

      end


      def cross_app_enabled?
        TingYun::Agent::CrossAppTracing.cross_app_enabled?
      end


      def save_referring_transaction_info(state,request)

        info = request[TY_ID_HEADER].split(';')
        tingyun_id_secret = info[0]
        client_transaction_id = info.find do |e|
          e.match(/x=/)
        end.split('=')[1] rescue nil
        client_req_id = info.find do |e|
          e.match(/r=/)
        end.split('=')[1] rescue nil

        state.client_tingyun_id_secret = tingyun_id_secret
        state.client_transaction_id = client_transaction_id
        state.transaction_sample_builder.trace.tx_id = client_transaction_id
        state.client_req_id = client_req_id
      end


      def insert_response_header(state, response_headers)
        if same_account?(state)
          txn = state.current_transaction
          unless txn.nil?
            set_response_headers(state, response_headers)
          end
          clear_client_tingyun_id_secret(state)
        end
      end

      def clear_client_tingyun_id_secret(state)
        state.client_tingyun_id_secret = nil
      end

      def same_account?(state)
        server_info = TingYun::Agent.config[:tingyunIdSecret].split('|')
        client_info = (state.client_tingyun_id_secret || '').split('|')
        if !server_info[0].nil? && server_info[0] == client_info[0] && !server_info[0].empty?
          return true
        else
          return false
        end
      end

      def set_response_headers(state, response_headers)
        response_headers[TY_DATA_HEADER] = TingYun::Support::Serialize::JSONWrapper.dump build_payload(state)
        TingYun::Agent.logger.debug("now,cross app will send response_headers  #{response_headers[TY_DATA_HEADER]}")
      end

      def build_payload(state)
        timings = state.timings

        payload = {
            :id => TingYun::Agent.config[:tingyunIdSecret].split('|')[1],
            :action => timings.transaction_name_or_unknown,
            :trId => timings.trace_id,
            :time => {
                :duration => timings.app_time_in_seconds,
                :qu => timings.queue_time_in_millis,
                :db => timings.sql_duration,
                :ex => timings.external_duration,
                :rds => timings.rds_duration,
                :mc => timings.mc_duration || 0,
                :mon => timings.mon_duration,
                :code => timings.app_execute_duration
            }
        }
        payload[:tr] = 1 if slow_action_tracer?(timings)
        payload[:r] = state.client_req_id unless state.client_req_id.nil?
        payload
      end

      def slow_action_tracer?(timings)
        timings.app_time_in_seconds > TingYun::Agent.config[:'nbs.action_tracer.action_threshold']
      end


    end
  end
end