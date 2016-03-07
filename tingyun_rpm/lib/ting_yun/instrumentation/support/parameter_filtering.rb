# encoding: utf-8



module TingYun
  module Instrumentation
    module Support
      module ParameterFiltering

        module_function

        def filter_rails_request_parameters(params)
          result = params.dup
          result.delete("controller")
          result.delete("action")
          result
        end
      end
    end
  end
end
