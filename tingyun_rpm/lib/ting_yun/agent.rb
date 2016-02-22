# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/configuration/manager'
require 'ting_yun/logger/startup_logger'
require 'ting_yun/frameworks'
require 'ting_yun/agent/transaction/transaction_state'
require 'ting_yun/agent/transaction'


module TingYun
  module Agent
    extend self

    @agent = nil
    @logger = nil
    @config = ::TingYun::Configuration::Manager.new

    attr_reader :config

    UNKNOWN_METRIC = '(unknown)'.freeze

    def agent
      return @agent if @agent
      TingYun::Agent.logger.warn("Agent unavailable as it hasn't been started.")
      TingYun::Agent.logger.warn(caller.join("\n"))
      nil
    end

    alias instance agent

    def agent=(new_instance)
      @agent = new_instance
    end


    def logger
      @logger || ::TingYun::Logger::StartupLogger.instance
    end

    def logger=(log)
      @logger = log
    end

    def reset_config
      @config.reset_to_defaults
    end


    # Record a value for the given metric name.
    #
    # This method should be used to record event-based metrics such as method
    # calls that are associated with a specific duration or magnitude.
    #
    # +metric_name+ should follow a slash separated path convention. Application
    # specific metrics should begin with "Custom/".
    #
    # +value+ should be either a single Numeric value representing the duration/
    # magnitude of the event being recorded, or a Hash containing :count,
    # :total, :min, :max, and :sum_of_squares keys. The latter form is useful
    # for recording pre-aggregated metrics collected externally.
    #
    # This method is safe to use from any thread.
    #
    # @api public
    def record_metric(metric_name, value) #THREAD_LOCAL_ACCESS
      return unless agent
      stats = TingYun::Metrics::Stats.create_from_hash(value) if value.is_a?(Hash)
      agent.stats_engine.tl_record_unscoped_metrics(metric_name, stats || value)
    end

    # Manual agent configuration and startup/shutdown

    # Call this to manually start the Agent in situations where the Agent does
    # not auto-start.
    #
    # When the app environment loads, so does the Agent. However, the
    # Agent will only connect to the service if a web front-end is found. If
    # you want to selectively monitor ruby processes that don't use
    # web plugins, then call this method in your code and the Agent
    # will fire up and start reporting to the service.
    #
    # Options are passed in as overrides for values in the
    # tingyun.yml, such as app_name.  In addition, the option +log+
    # will take a logger that will be used instead of the standard
    # file logger.  The setting for the tingyun.yml section to use
    # (ie, RAILS_ENV) can be overridden with an :env argument.
    #
    # @api public
    #
    def manual_start(options={})
      raise "Options must be a hash" unless Hash === options
      TingYun::Frameworks.init_start({ :'nbs.agent_enabled' => true, :sync_startup => true }.merge(options))
    end

    # Yield to a block that is run with a database metric name context.  This means
    # the Database instrumentation will use this for the metric name if it does not
    # otherwise know about a model.  This is re-entrant.
    #
    # @param [String,Class,#to_s] model the DB model class
    #
    # @param [String] method the name of the finder method or other method to
    # identify the operation with.
    #
    def with_database_metric_name(model, method = nil, product = nil, &block) #THREAD_LOCAL_ACCESS
      if txn = TingYun::Agent::TransactionState.tl_get.current_transaction
        txn.with_database_metric_name(model, method, product, &block)
      else
        yield
      end
    end


    # Notice the error with the given available options:
    #
    # * <tt>:uri</tt> => Request path, minus request params or query string
    # * <tt>:metric</tt> => The metric name associated with the transaction
    # * <tt>:custom_params</tt> => Custom parameters
    #
    # @api public
    #
    def notice_error(exception, options={})
      TingYun::Agent::Transaction.notice_error(exception, options)
      nil # don't return a noticed error datastructure. it can only hurt.
    end




  end
end