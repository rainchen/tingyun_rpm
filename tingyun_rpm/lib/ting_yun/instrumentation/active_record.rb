# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/instrumentation/support/active_record_helper'
require 'ting_yun/support/helper'
require 'ting_yun/agent/method_tracer'


module TingYun
  module Instrumentation
    module ActiveRecord

      def self.included(instrumented_class)
        instrumented_class.class_eval do
          unless instrumented_class.method_defined?(:log_without_tingyun_instrumentation)
            alias_method :log_without_tingyun_instrumentation, :log
            alias_method :log, :log_with_tingyun_instrumentation
            protected :log
          end
        end
      end

      def self.instrument
        if defined?(::ActiveRecord::VERSION::MAJOR) && ::ActiveRecord::VERSION::MAJOR.to_i >= 3
          ::TingYun::Instrumentation::Support::ActiveRecordHelper.instrument_additional_methods
        end

        ::ActiveRecord::ConnectionAdapters::AbstractAdapter.module_eval do
          include ::TingYun::Instrumentation::ActiveRecord
        end
      end

      def log_with_tingyun_instrumentation(*args, &block)
        sql, name, _ = args
        metrics = ::TingYun::Instrumentation::Support::ActiveRecordHelper.metrics_for(
                                                                    TingYun::Helper.correctly_encoded(name),
                                                                    TingYun::Helper.correctly_encoded(sql),
                                                                    @config && @config[:adapter])
        TingYun::Agent::MethodTracer.trace_execution_scoped(metrics) do
          log_without_tingyun_instrumentation(*args, &block)
        end
      end

    end
  end
end


TingYun::Support::LibraryDetection.defer do
  named :active_record

  depends_on do
    defined?(::ActiveRecord) && defined?(::ActiveRecord::Base) &&
        (!defined?(::ActiveRecord::VERSION) ||
            ::ActiveRecord::VERSION::MAJOR.to_i <= 3)
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing ActiveRecord instrumentation'
  end

  executes do
    require 'ting_yun/instrumentation/support/active_record_helper'

    if defined?(::Rails) && ::Rails::VERSION::MAJOR.to_i == 3
      ActiveSupport.on_load(:active_record) do
        ::TingYun::Instrumentation::ActiveRecord.instrument
      end
    else
      ::TingYun::Instrumentation::ActiveRecord.instrument
    end
  end

end

