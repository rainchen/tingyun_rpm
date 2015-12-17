# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent'
require 'ting_yun/support/exception'

module TingYun
  module Support
    module Serialize
      class Marshaller
        def parsed_error(error)
          error_type = error['error_type']
          error_message = error['message']

          exception = case error_type
                        when 'TingYun::Support::Exception::LicenseException'
                          TingYun::Support::Exception::LicenseException.new(error_message)
                        when 'TingYun::Support::Exception::ForceRestartException'
                          TingYun::Support::Exception::ForceRestartException.new(error_message)
                        when 'TingYun::Support::Exception::ForceDisconnectException'
                          TingYun::Support::Exception::ForceDisconnectException.new(error_message)
                        else
                          TingYun::Support::Exception::CollectorError.new("#{error['error_type']}: #{error['message']}")
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
            if data.has_key?('exception')
              raise parsed_error(data['exception'])
            elsif data.has_key?('result')
              return data['result']
            end
          end
          ::TingYun::Agent.logger.debug("Unexpected response from collector: #{data}")
          nil
        end
      end
    end
  end
end
