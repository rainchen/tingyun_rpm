# encoding: utf-8

# This module is intended to be included into both MiddlewareProxy and our
# internal middleware classes.
#
# Host classes must define two methods:
#
# * target: returns the original middleware being traced
# * category: returns the category for the resulting agent transaction
#             should be either :middleware or :rack
# * transaction_options: returns an options hash to be passed to
#                        Transaction.start when tracing this middleware.
#
# The target may be self, in which case the host class should define a
# #traced_call method, instead of the usual #call.

module TingYun
  module Rack
    module MiddlewareTracing

      def _nr_has_middleware_tracing
        true
      end

      def call(env)

      end
    end
  end
end
