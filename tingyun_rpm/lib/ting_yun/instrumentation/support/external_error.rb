module TingYun
  module Instrumentation
    module Support
      module ExternalError
        def capture_exception(response,state)
          if response.code =~ /^[4,5][0-9][0-9]$/ && response.code!='401'

          end
        end
      end
    end
  end
end
