# encoding: utf-8

require 'ting_yun/agent/transaction/traced_method_stack'
module TingYun
  module Agent

      # This is THE location to store thread local information during a transaction
      # Need a new piece of data? Add a method here, NOT a new thread local variable.
      class TransactionState

        # Request data
        attr_accessor :request, :transaction_sample_builder
        attr_reader   :current_transaction, :traced_method_stack
        # Execution tracing on current thread
        attr_accessor :untraced
        # Sql Sampler Transaction Data
        attr_accessor :sql_sampler_transaction_data



        def self.tl_get
          tl_state_for(Thread.current)
        end

        # This method should only be used by TransactionState for access to the
        # current thread's state or to provide read-only accessors for other threads
        #
        # If ever exposed, this requires additional synchronization
        def self.tl_state_for(thread)
          state = thread[:tingyun_transaction_state]

          if state.nil?
            state = TransactionState.new
            thread[:tingyun_transaction_state] = state
          end

          state
        end

        def initialize

          @current_transaction = nil
          @traced_method_stack = TingYun::Agent::TracedMethodStack.new
        end

        # This starts the timer for the transaction.
        def reset(transaction=nil)
          @request = nil
          @current_transaction = transaction
          @traced_method_stack.clear
          @transaction_sample_builder = nil
          @sql_sampler_transaction_data = nil
        end

        # TT's and SQL
        attr_accessor :record_tt, :record_sql

        def is_transaction_traced?
          @record_tt != false
        end

        def is_sql_recorded?
          @record_sql != false
        end


      end
  end
end
