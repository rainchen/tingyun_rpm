# encoding: utf-8
module TingYun
  module Instrumentation
    module Support
      module Timings
        def record_memcached_duration(_1, _2, duration)
          state = TingYun::Agent::TransactionState.tl_get
          if state
            state.timings.memchd_duration = state.timings.memchd_duration + duration * 1000
          end
        end
      end
    end
  end
end
