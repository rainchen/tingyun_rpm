# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/transaction'
require 'ting_yun/support/http_clients/uri_util'
require 'ting_yun/support/serialize/json_wrapper'
require 'ting_yun/instrumentation/support/external_error'
require 'ting_yun/agent/collector/transaction_sampler'


module TingYun
  module Agent
    module CrossAppTracing

      extend ::TingYun::Instrumentation::Support::ExternalError

      # Exception raised if there is a problem with cross app transactions.
      class Error < RuntimeError; end

      # The cross app id header for "outgoing" calls

      TY_ID_HEADER = 'X-Tingyun-Id'.freeze
      TY_DATA_HEADER = 'X-Tingyun-Tx-Data'.freeze


      module_function


      def tl_trace_http_request(request)
        state = TingYun::Agent::TransactionState.tl_get
        return yield unless state.execution_traced?
        return yield unless state.current_transaction #如果还没有创建Transaction，就发生跨应用，就直接先跳过跟踪。

        t0 = Time.now.to_f
        begin
          node = start_trace(state, t0, request)
          response = yield
          capture_exception(response, request, 'net%2Fhttp')
        rescue => e
          klass = "External/#{request.uri.to_s.gsub('/','%2F')}/net%2Fhttp"
          handle_error(e, klass)
          raise e
        ensure
          finish_trace(state, t0, node, request, response)
        end
        return response
      end

      def start_trace(state, t0, request)
        inject_request_headers(state, request) if cross_app_enabled?
        stack = state.traced_method_stack
        node = stack.push_frame(state, :http_request, t0)

        return node
      end

      def finish_trace(state, t0, node, request, response)
        t1 = Time.now.to_f
        duration = (t1- t0) * 1000
        state.external_duration = duration

        begin
          if request
            cross_app = response_is_cross_app?(response)

            metrics = metrics_for(request, response, cross_app)
            node_name = metrics.pop
            scoped_metric = metrics.pop

            ::TingYun::Agent.instance.stats_engine.record_scoped_and_unscoped_metrics(state, scoped_metric, metrics, duration)

            if node
              node.name = node_name
              add_transaction_trace_info(request, response, cross_app)
            end
          end
        rescue => err
          TingYun::Agent.logger.error "Uncaught exception while finishing an HTTP request trace", err
        ensure
          if node
            stack = state.traced_method_stack
            stack.pop_frame(state, node, node_name, t1)
          end
        end
      end


      def add_transaction_trace_info(request, response, cross_app)
        state = TingYun::Agent::TransactionState.tl_get
        ::TingYun::Agent::Collector::TransactionSampler.add_node_info(:uri => TingYun::Agent::HTTPClients::URIUtil.filter_uri(request.uri))
        if cross_app
          ::TingYun::Agent::Collector::TransactionSampler.tl_builder.set_txId_and_txData(state.client_transaction_id || state.request_guid,
                                                             TingYun::Support::Serialize::JSONWrapper.load(response[TY_DATA_HEADER].gsub("'",'"')))
        end
      end


      def metrics_for(request, response, cross_app)

        metrics = [ "External/NULL/ALL" ]

        if TingYun::Agent::Transaction.recording_web_transaction?
          metrics << "External/NULL/AllWeb"
        else
          metrics << "External/NULL/AllBackground"
        end

        if cross_app
          begin
            metrics.concat metrics_for_cross_app_response( request, response )
          rescue => err
            # Fall back to regular metrics if there's a problem with x-process metrics
            TingYun::Agent.logger.debug "%p while fetching x-process metrics: %s" %
                                            [ err.class, err.message ]
            metrics.concat metrics_for_regular_request( request )
          end
        else
          metrics.concat metrics_for_regular_request( request )
        end

        return metrics
      end


      def metrics_for_regular_request( request )
        metrics = []
        metrics << "External/#{request.uri.to_s.gsub('/','%2F')}/net%2Fhttp"
        metrics << "External/#{request.uri.to_s.gsub('/','%2F')}/net%2Fhttp"

        return metrics
      end


      def cross_app_enabled?
        TingYun::Agent.config[:tingyunIdSecret] && TingYun::Agent.config[:tingyunIdSecret].size > 0 &&
            TingYun::Agent.config[:'nbs.action_tracer.enabled'] &&
            TingYun::Agent.config[:'nbs.transaction_tracer.enabled']
      end

      # Inject the X-Process header into the outgoing +request+.
      def inject_request_headers(state, request)
        cross_app_id  = TingYun::Agent.config[:tingyunIdSecret] or
            raise TingYun::Agent::CrossAppTracing::Error, "no tingyunIdSecret configured"

        txn_guid = state.client_transaction_id || state.request_guid
        state.transaction_sample_builder.set_trace_id(txn_guid)
        request[TY_ID_HEADER] = "#{cross_app_id};c=1;x=#{txn_guid}"

      rescue TingYun::Agent::CrossAppTracing::Error => err
        TingYun::Agent.logger.debug "Not injecting x-process header", err
      end

      # Returns +true+ if Cross Application Tracing is enabled, and the given +response+
      # has the appropriate headers.
      def response_is_cross_app?( response )
        return false unless response
        return false unless response[TY_DATA_HEADER]
        return false unless cross_app_enabled?

        return true
      end

      # Return the set of metric objects appropriate for the given cross app
      # +response+.
      def metrics_for_cross_app_response(request, response )
        my_data =  TingYun::Support::Serialize::JSONWrapper.load response[TY_DATA_HEADER].gsub("'",'"')
        uri = "#{request.uri.to_s.gsub('/','%2F')}/net%2Fhttp"
        metrics = []
        metrics << "cross_app;#{my_data["id"]};#{my_data["action"]};#{uri}"
        metrics << "External/#{my_data["action"]}:#{uri}"

        return metrics
      end

    end
  end
end
