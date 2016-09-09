# encoding: utf-8
require 'ting_yun/support/serialize/json_wrapper'

module TingYun
  module Instrumentation
    module Support
      class JavascriptInstrument



        def browser_timing_header #THREAD_LOCAL_ACCESS
          return '' unless rum_enable? # unsupport insert script

          state = TingYun::Agent::TransactionState.tl_get
          return '' unless insert_js?(state)

          bt_config = browser_timing_config(state)

        end

        def rum_enable?
           Agent::Config[:'nbs.rum.enabled']
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
          data = {
              :id => TingYun::Agent.config[:tingyunIdSecret],
              :n => state.current_transaction.best_name ,
              :a => state.web_duration || 0,
              :q => "",
              :tid => state.trace_id
          }
          TingYun::Support::Serialize::JSONWrapper.dump(data)
        end

      end
    end
  end
 end
