# encoding: utf-8

module TingYun
  module Agent
    class Transaction
      class Attributes

        attr_accessor :agent_attributes
        def initialize
          @agent_attributes  = {}
          @custom_attributes = {}
        end

        def add_agent_attribute(key, value)
          return if value.nil?
          @agent_attributes[key] = value
        end

      end
    end
  end
end
