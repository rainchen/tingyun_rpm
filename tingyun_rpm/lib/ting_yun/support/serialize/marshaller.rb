# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent'
require 'ting_yun/support/exception'

module TingYun
  module Support
    module Serialize
      class Marshaller
        def parsed_error(error)
          error_code = error['errorCode']
          error_message = error['errorMessage']
          case error_code
            when 460
              raise TingYun::Support::Exception::LicenseException.new("#{error_code}: #{error_message}")
            when 461
              raise TingYun::Support::Exception::InvalidDataTokenException.new("#{error_code}: #{error_message}")
            when 462
              raise TingYun::Support::Exception::InvalidDataException.new("#{error_code}: #{error_message}")
            when 470
              raise TingYun::Support::Exception::ExpiredConfigurationException.new("#{error_code}: #{error_message}")
          end
        end

        def prepare(data, options={})
          encoder = options[:encoder] || default_encoder
          if data.respond_to?(:to_collector_array)
            data.to_collector_array(encoder)
          elsif data.kind_of?(Array)
            data.map { |element| prepare(element, options) }
          elsif data.kind_of?(Hash)
            data.each {|_k,_v| data[_k]=prepare(_v, options)}
          else
            data
          end
        end

        def default_encoder
          Encoders::Identity
        end

        def self.human_readable?
          false
        end

        def return_value_for_testing(data)
          return_value(data)
        end

        protected

        def return_value(data)
          if data.respond_to?(:has_key?)
            if data.has_key?('status')
              if data['status'] == "error"
                parsed_error(data['result'])
              elsif data['result']['enabled'] == false
                raise TingYun::Support::Exception::AgentEnableException.new("sorry，the application is unable to use the tingyun service now ")
              else
                return data
              end
            end
          end
          ::TingYun::Agent.logger.debug("Unexpected response from collector: #{data}")
          nil
        end
      end
    end
  end
end
