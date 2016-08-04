# encoding: utf-8

TingYun::Support::LibraryDetection.defer do

  named :rake

  depends_on do
    defined?(::Rake)&&
        !::TingYun::Agent.config[:'disable_rake'] &&
        ::TingYun::Agent.config[:'rake.tasks'].any? &&
        ::TingYun::Agent::Instrumentation::RakeInstrumentation.supported_version?
  end

  executes do
    ::TingYun::Agent.logger.info 'Installing deferred Rake instrumentation'
  end

  executes do
    module Rake
      class Task
        alias_method :invoke_without_tingyun, :invoke
        def invoke(*args)
          unless TingYun::Agent::Instrumentation::RakeInstrumentation.should_trace? name
            invoke_without_tingyun(*args)
          end

          TingYun::Agent::Instrumentation::RakeInstrumentation.before_invoke_transaction

          state = TingYun::Agent::TransactionState.tl_get
          TingYun::Agent::Transaction.wrap(state, "BackgroundAction/Rake/#{name}", :rake)  do
            invoke_without_tingyun(*args)
          end
        end
      end
    end
  end
end

module TingYun
  module Agent
    module Instrumentation
      module RakeInstrumentation

        def self.supported_version?
          ::TingYun::VersionNumber.new(::Rake::VERSION) >= ::TingYun::VersionNumber.new("0.9.0")
        end

        def self.before_invoke_transaction
          ensure_at_exit
        end

        def self.should_trace? name
          TingYun::Agent.config[:'rake.tasks'].any? do |task|
            task == name
          end
        end

        def self.ensure_at_exit
          return if @installed_at_exit

          at_exit do
            # The agent's default at_exit might not default to installing, but
            # if we are running an instrumented rake task, we always want it.
            TingYun::Agent.shutdown
          end

          @installed_at_exit = true
        end
      end
    end
  end
 end