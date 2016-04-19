# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/support/http_clients/uri_util'

module TingYun
  module Agent
    module CrossAppTracing

      # Exception raised if there is a problem with cross app transactions.
      class Error < RuntimeError; end

      # The cross app id header for "outgoing" calls
      NR_ID_HEADER = 'X-Tingyun-Id'

      # The cross app transaction header for "outgoing" calls
      NR_TXN_HEADER = 'X-Tingyun-Tx-Id'

      module_function

      def tl_trace_http_request(request)
        t0 = Time.now
        state = TingYun::Agent::TransactionState.tl_get
        return yield unless state.execution_traced?
        begin
          node = start_trace(state, t0, request)
          response = yield
        ensure
          finish_trace(state, t0, node, request, response)
        end
        return response
      end

      def start_trace(state, t0, request)
        inject_request_headers(state, request) if cross_app_enabled?
        stack = state.traced_method_stack
        node = stack.push_frame(state,:http_request,t0)

        return node
      end

      def finish_trace(state, t0, node, request, response)
        t1 = Time.now
        duration = (t1.to_f - t0.to_f) * 1000

        begin
          if request
            metrics = metrics_for(request, response)
            scoped_metric = metrics[-1]

            stats_engine.record_scoped_and_unscoped_metrics(state, scoped_metric, metrics, duration)

            if node
              node.name = scoped_metric
              add_transaction_trace_info(request, response)
            end
          end
        ensure
          if node
            stack = state.traced_method_stack
            stack.pop_frame(state, node, scoped_metric, t1)
          end
        end
      rescue => err
        TingYun::Agent.logger.error "Uncaught exception while finishing an HTTP request trace", err

      end

      def add_transaction_trace_info(request, response)
        filtered_uri = TingYun::Agent::HTTPClients::URIUtil.filter_uri request.uri
        transaction_sampler.add_node_info(:uri => filtered_uri)
      end

      def metrics_for(request, response)
        metrics = common_metrics(request)

        if response && response_is_crossapp?( response )
          metrics.concat metrics_for_regular_request( request )
        else
          metrics.concat metrics_for_regular_request( request )
        end

        return metrics
      end

      def common_metrics(request)
        metrics = [ "External/NULL/ALL" ]

        metrics << "External/NULL/AllWeb"

        return metrics
      end

      def metrics_for_regular_request( request )
        metrics = []
        metrics << "External/#{request.host}/#{request.type}/#{request.method}"

        return metrics
      end

      def stats_engine
        ::TingYun::Agent.instance.stats_engine
      end

      def transaction_sampler
        ::TingYun::Agent.instance.transaction_sampler
      end

      def cross_app_enabled?
        web_action_tracer_enabled? && cross_application_tracer_enabled?
      end

      def web_action_tracer_enabled?
        TingYun::Agent.config[:'nbs.transaction_tracer.enabled']
      end

      def cross_application_tracer_enabled?
        TingYun::Agent.config[:'nbs.transaction_tracer.enabled']
      end

      # Inject the X-Process header into the outgoing +request+.
      def inject_request_headers(state, request)
        cross_app_id  = TingYun::Agent.config[:tingyunIdSecret] or
            raise TingYun::Agent::CrossAppTracing::Error, "no tingyunIdSecret configured"

        txn_guid = state.request_guid

        request[NR_ID_HEADER]  = cross_app_id
        request[NR_TXN_HEADER] = txn_guid

      rescue TingYun::Agent::CrossAppTracing::Error => err
        TingYun::Agent.logger.debug "Not injecting x-process header", err
      end

      # Returns +true+ if Cross Application Tracing is enabled, and the given +response+
      # has the appropriate headers.
      def response_is_crossapp?( response )
        return false unless cross_app_enabled?
        return true
      end

      # Return the set of metric objects appropriate for the given cross app
      # +response+.
      def metrics_for_crossapp_response( request, response )
        xp_id, txn_name, _q_time, _r_time, _req_len, _ = extract_appdata( response )

        check_crossapp_id( xp_id )
        check_transaction_name( txn_name )

        metrics = []
        metrics << "ExternalTransaction/NULL/#{cross_app_id}"

        return metrics
      end


    end
  end
end
