# encoding: utf-8
module TingYun
  module Agent

    class Transaction
      class Apdex
        attr_accessor :apdex_start

        def initialize(start_time)
          @apdex_start = start_time
        end


      end
    end
  end
end
