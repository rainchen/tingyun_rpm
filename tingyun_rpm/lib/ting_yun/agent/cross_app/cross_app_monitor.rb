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

        events.subscribe(:before_call) do |env| #THREAD_LOCAL_ACCESS
          if TingYun::Agent::CrossAppTracing.cross_app_enabled?
            state = TingYun::Agent::TransactionState.tl_get
            state.save_referring_transaction_info(env[TY_ID_HEADER].split(';')) if env[TY_ID_HEADER]
          end
        end

        events.subscribe(:after_call) do |_status_code, headers, _body| #THREAD_LOCAL_ACCESS
          state = TingYun::Agent::TransactionState.tl_get
          state.queue_duration = state.current_transaction.apdex.queue_time
          state.web_duration = (Time.now - state.current_transaction.start_time) * 1000
          insert_response_header(state, headers)
        end

      end


      def insert_response_header(state, response_headers)
        if state.same_account?
          txn = state.current_transaction
          if txn
            # set_response_headers
            response_headers[TY_DATA_HEADER] = TingYun::Support::Serialize::JSONWrapper.dump build_payload(state)
            TingYun::Agent.logger.debug("now,cross app will send response_headers  #{response_headers[TY_DATA_HEADER]}")
          end
          state.client_tingyun_id_secret = nil #clear_client_tingyun_id_secret
        end
      end


      def build_payload(state)
        payload = {
            :id => TingYun::Agent.config[:tingyunIdSecret].split('|')[1],
            :action => state.current_transaction.best_name,
            :trId => state.transaction_sample_builder.trace.guid,
            :time => {
                :duration => state.web_duration,
                :qu => state.queue_duration,
                :db => state.sql_duration,
                :ex => state.external_duration,
                :rds => state.rds_duration,
                :mc => state.mc_duration,
                :mon => state.mon_duration,
                :code => state.execute_duration
            }
        }
        payload[:tr] = 1 if state.slow_action_tracer?
        payload[:r] = state.client_req_id if state.client_req_id
        payload
      end
    end
  end
end