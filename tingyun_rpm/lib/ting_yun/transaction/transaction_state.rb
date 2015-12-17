# encoding: utf-8

module TingYun
  module Agent
    class TransactionState

      # Request data
      attr_accessor :request

      # This method should only be used by TransactionState for access to the
      # current thread's state or to provide read-only accessors for other threads
      #
      # If ever exposed, this requires additional synchronization
      def self.tl_state_for(thread)
        state = thread[:tingyun_transaction_state] ||= TransactionState.new
        thread[:tingyun_transaction_state] = state

        state
      end

      def self.tl_get
        tl_state_for(Thread.current)
      end

      def self.tl_clear_for_testing
        Thread.current[:tingyun_transaction_state] = nil
      end

      # This starts the timer for the transaction.
      def reset(transaction=nil)
        @current_transaction = transaction
      end

    end
  end
end
