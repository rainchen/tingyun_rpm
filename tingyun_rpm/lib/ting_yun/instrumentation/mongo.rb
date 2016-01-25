# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/method_tracer'

module TingYun
  module Instrumentation
    module Mongo
      extend self

      def install_mongo_instrumentation
        hook_instrument_methods
        instrument_save
        instrument_ensure_index
      end

      def hook_instrument_methods
        hook_instrument_method(::Mongo::Collection)
        hook_instrument_method(::Mongo::Connection)
        hook_instrument_method(::Mongo::Cursor)
        hook_instrument_method(::Mongo::CollectionWriter) if defined?(::Mongo::CollectionWriter)
      end


      def hook_instrument_method(target_class)
        target_class.class_eval do
          include TingYun::Agent::MethodTracer

          # It's key that this method eats all exceptions, as it rests between the
          # Mongo operation the user called and us returning them the data. Be safe!
          def new_relic_notice_statement(t0, payload, name)
            statement = NewRelic::Agent::Datastores::Mongo::StatementFormatter.format(payload, name)
            if statement
              NewRelic::Agent.instance.transaction_sampler.notice_nosql_statement(statement, (Time.now - t0).to_f)
            end
          rescue => e
            NewRelic::Agent.logger.debug("Exception during Mongo statement gathering", e)
          end

          def new_relic_generate_metrics(operation, payload = nil)
            payload ||= { :collection => self.name, :database => self.db.name }
            NewRelic::Agent::Datastores::Mongo::MetricTranslator.metrics_for(operation, payload)
          end

          def instrument_with_ting_yun_trace(name, payload = {}, &block)
            metrics = new_relic_generate_metrics(name, payload)

            trace_execution_scoped(metrics) do
              t0 = Time.now

              result = NewRelic::Agent.disable_all_tracing do
                instrument_without_ting_yun_trace(name, payload, &block)
              end

              new_relic_notice_statement(t0, payload, name)
              result
            end
          end

          alias_method :instrument_without_ting_yun_trace, :instrument
          alias_method :instrument, :instrument_with_ting_yun_trace
        end
      end

    end
  end
end

TingYun::Support::LibraryDetection.defer do
  named :mongo

  depends_on do
    defined?(::Mongo)
  end

  depends_on do
    require 'ting_yun/agent/datastore/mongo'

    if TingYun::Agent::Datastores::Mongo.unsupported_2x?
      TingYun::Agent.logger.log_once(:info, :mongo2, 'Detected unsupported Mongo 2, upgrade your Mongo Driver to 2.1 or newer for instrumentation')
    end
    TingYun::Agent::Datastore::Mongo.supported_version?

  end

  executes do
    TingYun::Agent.logger.info 'Installing Mongo instrumentation'
  end

  executes do
    if TingYun::Agent::Datastores::Mongo.monitoring_enabled?

    else
      TingYun::Instrumentation::Mongo.install_mongo_instrumentation
    end
  end
end
