# encoding: utf-8
require 'ting_yun/agent/transaction/transaction_state'
module TingYun
  module Agent
    module Datastore
      module MetricHelper


        ALL_WEB = "AllWeb".freeze
        ALL_BACKGROUND = "AllBackground".freeze
        ALL = "All".freeze

        def self.metric_name(product, collection, operation)
          "Database #{product}/#{collection}/#{operation}"
        end

        def self.product_suffixed_rollup(product,suffix)
          "Database #{product}/NULL/#{suffix}"
        end



        def self.metrics_for(product, operation, collection = nil, generic_product = nil)
          if overrides = overridden_operation_and_collection   # [method, model_name, product]
            if should_override?(overrides, product, generic_product)
              operation  = overrides[0] || operation
              collection = overrides[1] || collection
            end
          end
          metrics = [ALL_WEB,ALL]
          metrics << operation
          metrics = metrics.map do |suffix|
            product_suffixed_rollup(product,suffix)
          end

          metrics.unshift metric_name(product, collection, operation)
          metrics
        end

        # Allow Transaction#with_database_metric_name to override our
        # collection and operation
        def self.overridden_operation_and_collection #THREAD_LOCAL_ACCESS
          state = TingYun::Agent::TransactionState.tl_get
          txn   = state.current_transaction
          txn ? txn.instrumentation_state[:datastore_override] : nil
        end

        # If the override declared a product affiliation, abide by that
        # ActiveRecord has database-specific product names, so we recognize
        # it by the generic_product it passes.
        def self.should_override?(overrides, product, generic_product)
          override_product = overrides[2]

          override_product.nil? ||
              override_product == product ||
              override_product == generic_product
        end

      end
    end
  end
end

