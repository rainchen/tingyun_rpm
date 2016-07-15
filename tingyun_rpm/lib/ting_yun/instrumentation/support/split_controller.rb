module TingYun
  module Instrumentation
    module Support
      module SplitController
        HTTP = {
          'GET' => 1,
          'POST' => 2,
          'PUT' => 3,
          'DELETE' => 4,
          'HEAD' => 5
        }

        RULE = {
          1=> :eql?,
          2=> :start_with?,
          3=> :end_with?,
          4=> :include?
        }

        def match?(event)
          rules.each do |rule|
            if method_match?(event.method, rule[:match]['method'])
              if url_match?(event.path,rule[:match][:match], rule[:match]['value'])

              end
            end
          end
        end



        def rules
          TingYun::Agent.config[:'']
        end

        def method_match?(method, rule)
          rule[:match]['method'] == 0 || rule == HTTP[method]
        end

        def url_match?(url, rule, value)
          url.send(RULE[rule], value)
        end

        def params_match?

        end
      end
    end
  end
end