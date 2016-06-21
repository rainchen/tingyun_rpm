# encoding: utf-8

TingYun::Support::LibraryDetection.defer do

  named :net_http

  depends_on do
    defined?(Net) && defined?(Net::HTTP)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Net instrumentation'
    require 'ting_yun/agent/cross_app/cross_app_tracing'
    require 'ting_yun/http/net_http_request'
  end

  executes do
    class Net::HTTP
      def request_with_tingyun_trace(request, *args, &block)
        tingyun_request = TingYun::Http::NetHttpRequest.new(self, request)

        TingYun::Agent::CrossAppTracing.tl_trace_http_request(tingyun_request) do
          TingYun::Agent.disable_all_tracing do
            request_without_tingyun_trace(request, *args, &block )
          end
        end
      end

      alias :request_without_tingyun_trace :request
      alias :request :request_with_tingyun_trace


      class << self
        def get_response_with_tingyun(uri_or_host, path = nil, port = nil, &block)
          begin
            get_response_without_tingyun(uri_or_host, path = nil, port = nil, &block)
          rescue => e
            info = ::TingYun::Instrumentation::Support::ExternalError::ERROR_CODE.find {|k,v| e.class.to_s.include? k.to_s }
            klass = "External/#{uri_or_host.to_s.gsub('/','%2F')}/net%2Fhttp"
            e.instance_variable_set(:@tingyun_klass, klass)
            e.instance_variable_set(:@tingyun_external, true)
            e.instance_variable_set(:@tingyun_trace, caller.reject! { |t| t.include?('tingyun_rpm') })
            if info.nil?
              e.instance_variable_set(:@tingyun_code, 1000)
            else
              e.instance_variable_set(:@tingyun_code, info[1])
            end
            TingYun::Agent.notice_error(e)
            raise e
          end
        end
        alias get_response_without_tingyun get_response
        alias get_response get_response_with_tingyun
      end
    end
  end
end