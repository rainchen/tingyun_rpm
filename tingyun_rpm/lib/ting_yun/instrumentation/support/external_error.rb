# encoding: utf-8
require 'ting_yun/agent'
require 'ting_yun/support/exception'

module TingYun
  module Instrumentation
    module Support
      module ExternalError


        module_function

        def capture_exception(response,request,type)
          if !response.nil? && response.code =~ /^[4,5][0-9][0-9]$/ && response.code!='401'
            e = TingYun::Support::Exception::InternalServerError.new("#{response.code}: #{response.message}")
            klass = "External/#{request.uri.to_s.gsub('/','%2F')}/#{type}"
            set_attributes(e, klass)
            e.instance_variable_set(:@tingyun_code, response.code)
            TingYun::Agent.notice_error(e)
          end
        end

        def handle_error(e,klass)

          set_attributes(e, klass)
          case e
            when Errno::ECONNREFUSED
              e.instance_variable_set(:@tingyun_code, 902)
            when SocketError
              e.instance_variable_set(:@tingyun_code, 901)
            when OpenSSL::SSL::SSLError
              e.instance_variable_set(:@tingyun_code, 908)
            when Timeout::Error
              e.instance_variable_set(:@tingyun_code, 903)
            else
              e.instance_variable_set(:@tingyun_code, 1000)
          end

          TingYun::Agent.notice_error(e)
        end

        def set_attributes(exception, klass)
          begin
            exception.instance_variable_set(:@tingyun_klass, klass)
            exception.instance_variable_set(:@tingyun_external, true)
            trace = caller.reject! { |t| t.include?('tingyun_rpm') }
            trace = trace.first(20)
            exception.instance_variable_set(:@tingyun_trace, trace)
          rescue => e
            TingYun::Agent.logger.warn("Failed to set attributes for : #{exception}: ", e)
          end
        end

      end
    end
  end
end
