# encoding: utf-8

module TingYun
  class Constants

    SUBTRANSACTION_PREFIX        = 'Nested/'.freeze
    CONTROLLER_PREFIX            = 'Controller/'.freeze
    MIDDLEWARE_PREFIX            = 'Middleware/Rack/'.freeze
    TASK_PREFIX                  = 'OtherTransaction/Background/'.freeze
    RACK_PREFIX                  = 'WebTransaction/Rack/'.freeze
    SINATRA_PREFIX               = 'WebTransaction/Sinatra/'.freeze
    GRAPE_PREFIX                 = 'WebTransaction/Grape/'.freeze
    OTHER_TRANSACTION_PREFIX     = 'OtherTransaction/'.freeze
    WEB_TRANSACTION_PREFIX       = 'WebTransaction/'.freeze

    CONTROLLER_MIDDLEWARE_PREFIX = 'Controller/Middleware/Rack'.freeze

    WEB_SUMMARY_METRIC   = 'WebTransaction'.freeze
    OTHER_SUMMARY_METRIC = 'OtherTransaction/all'.freeze

    APDEX_S = 'S'.freeze
    APDEX_T = 'T'.freeze
    APDEX_F = 'F'.freeze
    APDEX_METRIC = 'Apdex'.freeze

    QUEUE_TIME_METRIC = 'WebFrontend/QueueTime'.freeze

    NESTED_TRACE_STOP_OPTIONS    = { :metric => true }.freeze
    WEB_TRANSACTION_CATEGORIES   = [:controller, :uri, :rack, :sinatra, :grape, :middleware].freeze
    TRANSACTION_NAMING_SOURCES   = [:child, :api].freeze

    MIDDLEWARE_SUMMARY_METRICS   = ['Middleware/all'.freeze].freeze
    EMPTY_SUMMARY_METRICS        = [].freeze

    TRACE_OPTIONS_SCOPED         = {:metric => true, :scoped_metric => true}.freeze
    TRACE_OPTIONS_UNSCOPED       = {:metric => true, :scoped_metric => false}.freeze

    TRACE_IGNORE_OPTIONS         = {:metric => false}.freeze

    UNKNOWN_METRIC = '(unknown)'.freeze

    FAILED_TO_STOP_MESSAGE = "Failed during Transaction.stop because there is no current transaction"

  end
end
