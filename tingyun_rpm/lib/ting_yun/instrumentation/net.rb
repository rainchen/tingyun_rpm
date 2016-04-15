# encoding: utf-8

TingYun::Support::LibraryDetection.defer do

  named :net_http

  depends_on do
    defined?(Net) && defined?(Net::HTTP)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Net instrumentation'
    require 'ting_yun/agent/cross_app_tracing'
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

      alias request_without_tingyun_trace request
      alias request request_with_tingyun_trace
    end
  end
end