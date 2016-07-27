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
          return if value.nil?
          @agent_attributes[key] = value
        end

        def merge_request_parameters(hash)
          @request_params.merge!(hash) unless hash
        end
      end
    end
  end
end
