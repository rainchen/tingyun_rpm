# encoding: utf-8

TingYun::Support::LibraryDetection.defer do

  named :net_http

  depends_on do
    defined?(Net) && defined?(Net::HTTP)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing Net instrumentation'
    require 'ting_yun/agent/cross_app_tracing'
    # require 'new_relic/agent/http_clients/net_http_wrappers'
  end

  executes do
    class Net::HTTP
      def request_with_tingyun_trace(request, *args, &block)
        TingYun::Agent::CrossAppTracing.tl_trace_http_request(request) do
          
        end
      end

      alias request_without_tingyun_trace request
      alias request request_with_tingyun_trace
    end
  end
end