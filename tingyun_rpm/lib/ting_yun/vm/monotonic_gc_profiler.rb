# encoding: utf-8
require 'ting_yun/support/language_support'
module TingYun
  module Vm
    class MonotonicGCProfiler
      def initialize
        @total_time_s = 0
        @lock         = Mutex.new
      end

      def total_time_s
        if TingYun::LanguageSupport.gc_profiler_enabled?
          # There's a race here if the next two lines don't execute as an atomic
          # unit - we may end up double-counting some GC time in that scenario.
          # Locking around them guarantees atomicity of the read/increment/reset
          # sequence.
          @lock.synchronize do
            # return values in seconds.
            @total_time_s += ::GC::Profiler.total_time
            ::GC::Profiler.clear
          end
        else
          TingYun::Agent.logger.log_once(:warn, :gc_profiler_disabled,
                                          "Tried to measure GC time, but GC::Profiler was not enabled.")
        end

        @total_time_s
      end
    end
  end
end
