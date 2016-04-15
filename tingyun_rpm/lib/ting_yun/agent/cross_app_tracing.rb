# encoding: utf-8

require 'ting_yun/agent/transaction/transaction_state'

module TingYun
  module Agent
    module CrossAppTracing
      module_function

      def tl_trace_http_request(request)
        t0 = Time.now
        state = TingYun::Agent::TransactionState.tl_get

        begin
          node = start_trace(state, t0, request)
          response = yield
        ensure
          finish_trace(state, t0, node, request, response)
        end

      end

      def start_trace
        stack = state.traced_method_stack
        node = stack.push_frame(state,:http_request,t0)

        return node
      end

      def finish_trace(state, t0, node, request, response)
        t1 = Time.now
        duration = (t1.to_f - t0.to_f) * 1000

        begin
          if request
            metrics = metrics_for(request)
            scoped_metric = metrics.pop

            stats_engine.record_scoped_and_unscoped_metrics(state, scoped_metric, metrics, duration)

            if node
              node.name = scoped_metric
            end
          end
        ensure
          if node
            stack = state.traced_method_stack
            stack.pop_frame(state, node, scoped_metric, t1)
          end
        end

      end

      def metrics_for(request)
        metrics = common_metrics( request )
        metrics.concat metrics_for_regular_request( request )

        return metrics
      end

      def common_metrics(request)
        metrics = [ "External/all" ]
        metrics << "External/#{request.host}/all"

        if TingYun::Agent::Transaction.recording_web_transaction?
          metrics << "External/allWeb"
        else
          metrics << "External/allOther"
        end

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

    end
  end
end
