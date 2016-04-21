# encoding: utf-8
require 'ting_yun/agent/cross_app/inbound_request_monitor'
require 'ting_yun/agent/cross_app/cross_app_tracing'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent'


module TingYun
  module Agent
    class CrossAppMonitor < TingYun::Agent::InboundRequestMonitor


      TY_ID_HEADER = 'X-Tingyun-Id'.freeze
      TY_DATA_HEADER = 'X-Tingyun-Tx-Data'.freeze


      def on_finished_configuring(events)
        register_event_listeners(events)
      end

      # Expected sequence of events:
      #   :before_call will save our cross application request id to the thread
      #   :after_call will write our response headers/metrics and clean up the thread
      def register_event_listeners(events)
        TingYun::Agent.logger.debug("Wiring up Cross Application Tracing to events after finished configuring")

        events.subscribe(:before_call) do |env| #THREAD_LOCAL_ACCESS
          if cross_app_enabled?
            state = TingYun::Agent::TransactionState.tl_get

            save_referring_transaction_info(state, env)
          end
        end

        events.subscribe(:after_call) do |_status_code, headers, _body| #THREAD_LOCAL_ACCESS
          state = TingYun::Agent::TransactionState.tl_get

          insert_response_header(state, headers)
        end

      end


      def cross_app_enabled?
        TingYun::Agent::CrossAppTracing.cross_app_enabled?
      end


      def save_referring_transaction_info(request)
        info = request[TY_ID_HEADER].split(';')
        tingyun_id_secret = info[0]
        client_transaction_id = info.find do |e|
          e.split('=')[1] if e.match(/x=/)
        end
        client_req_id = info.find do |e|
          e.split('=')[1] if e.match(/r=/)
        end

        state.client_tingyun_id_secret = tingyun_id_secret
        state.client_transaction_id = client_transaction_id
        state.client_req_id = client_req_id

      end


      def insert_response_header(state, response_headers)
        if same_account?
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

      def same_account?
        server_info = TingYun::Agent.config[:tingyunIdSecret].split('|')
        client_info = (state.client_tingyun_id_secret || '').split('|')
        if server_info.size == 2 && client_info.size == 2 && server_info[0] == client_info[0]
          return true
        else
          return false
        end
      end

      def set_response_headers(state, response_headers)
        response_headers[TY_DATA_HEADER] = build_payload(state)
      end

      def build_payload(state)
        payload = {
            :id => TingYun::Agent.config[:tingyunIdSecret].split('|')[1],
            :action => state.current_transaction.best_name,
            :trId => state.request_guid,
            :time => {
                :duration => state.web_duration,
                :qu => state.queue_duration,
                :db => state.sql_duration,
                :ex => state.external_duration,
                :rds => state.rds_duration,
                :mc => state.mc_duration,
                :mon => state.mon_duration,
                :code => execute_duration(state)
            }
        }
        payload[:tr] = 1 if slow_action_tracer?
      end

      def slow_action_tracer?
        if state.current_transaction.duration > TingYun::Agent.config[:'nbs.action_tracer.action_threshold']
          return true
        else
          return false
        end
      end

      def execute_duration(state)
        state.web_duration - state.queue_duration - state.sql_duration - state.external_duration - state.rds_duration - state.mc_duration - state.mon_duration
      end
    end
  end
end