module TingYun
  module Agent
    module Collector
      class CrossAppErrorSampler

        MAX_SAMPLES = 10

        attr_reader :sampler
        def initialize
          @sampler = {}
          @lock = Mutex.new
        end

        def notice_error(exception, options={})

        end

      end
    end
  end
end
