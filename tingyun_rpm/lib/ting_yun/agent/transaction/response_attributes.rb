# encoding: utf-8

module TingYun
  module Agent
    class Transaction
      class ResponseAttributes
        def initialize
          @custom_attributes = {}
          @agent_attributes  = {}
        end

        def add_agent_attribute(key, value)
          return if value.nil?
          @agent_attributes[key] = value
        end

      end
    end
  end
end