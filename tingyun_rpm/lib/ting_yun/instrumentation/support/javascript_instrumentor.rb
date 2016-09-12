# encoding: utf-8
require 'ting_yun/support/serialize/json_wrapper'

module TingYun
  module Instrumentation
    module Support
      module JavascriptInstrument

        module_function

        def browser_timing_header #THREAD_LOCAL_ACCESS
          return '' unless rum_enable? # unsupport insert script

          state = TingYun::Agent::TransactionState.tl_get
          return '' unless insert_js?(state)

          bt_config = browser_timing_config(state)
        rescue => e
          ::TingYun::Agent.logger.debug "Failure during RUM browser_timing_header construction", e
          ''
        end

        def rum_enable?
           TingYun::Agent.config[:'nbs.rum.enabled']
        end

        def insert_js?(state)
          if !state.current_transaction
            ::TingYun::Agent.logger.debug "Not in transaction. Skipping browser instrumentation."
            false
          elsif !state.transaction_traced?
            ::TingYun::Agent.logger.debug "Transaction is not traced. Skipping browser instrumentation."
            false
          elsif !state.execution_traced?
            ::TingYun::Agent.logger.debug "Execution is not traced. Skipping browser instrumentation."
            false
          else
            true
          end
        end


        def browser_timing_config(state)
          timings = state.timings

          data = {
              :id => TingYun::Agent.config[:tingyunIdSecret],
              :n => timings.transaction_name_or_unknown ,
              :a => timings.app_time_in_millis,
              :q => timings.queue_time_in_millis,
              :tid => timings.trace_id
          }
          TingYun::Support::Serialize::JSONWrapper.dump(data)
        end

      end
    end
  end
 end
