# encoding: utf-8

module TingYun
  module Agent
    class Transaction
      class Attributes

        attr_accessor :agent_attributes, :request_params
        def initialize
          @agent_attributes  = {}
          @request_params = {}
        end

        def add_agent_attribute(key, value)
          @agent_attributes[key] = value if value
        end

        def merge_request_parameters(hash)
          @request_params.merge!(hash) if hash
        end

        def assign_agent_attributes(http_response_code,response_content_type)
          add_agent_attribute(:threadName,  "pid-#{$$}");
          add_agent_attribute(:httpStatus, http_response_code.to_s)
          add_agent_attribute(:contentType, response_content_type.to_s)
        end
      end
    end
  end
end
