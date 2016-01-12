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

          exception = case error_code
                        when 460
                          TingYun::Support::Exception::LicenseException.new(error_message)
                        when 461
                          TingYun::Support::Exception::InvalidDataTokenException.new(error_message)
                        when 462
                          TingYun::Support::Exception::InvalidDataException.new(error_message)
                        when 470
                          TingYun::Support::Exception::ExpiredConfigurationException.new("error_message")
                        else
                          TingYun::Support::Exception::CollectorError.new("#{error_code}: #{error_message}")
                      end

          exception
        end

        def prepare(data, options={})
          encoder = options[:encoder] || default_encoder
          if data.respond_to?(:to_collector_array)
            data.to_collector_array(encoder)
          elsif data.kind_of?(Array)
            data.map { |element| prepare(element, options) }
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
            if data.has_key?('status') && data.has_key?('result')
              if data['status'] =="error"
                raise parsed_error(data['result'])
              else
                return data['result']
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
