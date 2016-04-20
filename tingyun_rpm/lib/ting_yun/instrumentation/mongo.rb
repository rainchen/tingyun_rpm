# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/instrumentation/support/metric_translator'

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
          require 'ting_yun/agent/method_tracer'

          def ting_yun_generate_metrics(operation, payload = nil)
            payload ||= { :collection => self.name, :database => self.db.name }
            TingYun::Instrumentation::Support::MetricTranslator.metrics_for(operation, payload)
          end

          def instrument_with_ting_yun_trace(name, payload = {}, &block)
            metrics = ting_yun_generate_metrics(name, payload)

            TingYun::Agent::MethodTracer.trace_execution_scoped(metrics, nil, method(:record_mongo_duration)) do
              instrument_without_ting_yun_trace(name, payload, &block)
            end
          end

          alias_method :instrument_without_ting_yun_trace, :instrument
          alias_method :instrument, :instrument_with_ting_yun_trace
        end
      end

      def instrument_save
        ::Mongo::Collection.class_eval do
          def save_with_ting_yun_trace(doc, opts = {}, &block)
            metrics = ting_yun_generate_metrics(:save)
            TingYun::Agent::MethodTracer.trace_execution_scoped(metrics, nil, method(:record_mongo_duration)) do
              save_without_ting_yun_trace(doc, opts, &block)
            end
          end

          alias_method :save_without_ting_yun_trace, :save
          alias_method :save, :save_with_ting_yun_trace
        end
      end

      def instrument_ensure_index
        ::Mongo::Collection.class_eval do
          def ensure_index_with_ting_yun_trace(spec, opts = {}, &block)
            metrics = ting_yun_generate_metrics(:ensureIndex)
            TingYun::Agent::MethodTracer.trace_execution_scoped(metrics, nil, method(:record_mongo_duration)) do
              ensure_index_with_out_ting_yun_trace(spec, opts, &block)
            end
          end

          alias_method :ensure_index_with_out_ting_yun_trace, :ensure_index
          alias_method :ensure_index, :ensure_index_with_ting_yun_trace
        end
      end

      def record_mongo_duration(duration)
        state = TingYun::Agent::TransactionState.tl_get
        unless state.nil?
          state.mon_duration += duration * 1000
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
    TingYun::Agent::Datastore::Mongo.supported_version? && !TingYun::Agent::Datastore::Mongo.unsupported_2x?
  end

  executes do
    TingYun::Agent.logger.info 'Installing Mongo instrumentation'
  end

  executes do
    TingYun::Instrumentation::Mongo.install_mongo_instrumentation
  end
end
