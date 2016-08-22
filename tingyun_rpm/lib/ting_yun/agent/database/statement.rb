# encoding: utf-8
require 'ting_yun/support/helper'
require 'ting_yun/agent/database/explain_plan_helpers'

module TingYun
  module Agent
    module Database
      class Statement
        include TingYun::Agent::Database::ExplainPlanHelpers

        attr_accessor :sql, :config, :explainer


        def initialize(sql, config={}, explainer=nil)
          @sql = TingYun::Agent::Database.capture_query(sql)
          @config = config
          @explainer = explainer
        end

        def adapter
          return unless @config

          @adapter ||= if @config[:adapter]
                         symbolized_adapter(@config[:adapter].to_s.downcase)
                       elsif @config[:uri] && @config[:uri].to_s =~ /^jdbc:([^:]+):/
                         # This case is for Sequel with the jdbc-mysql, jdbc-postgres, or jdbc-sqlite3 gems.
                         symbolized_adapter($1)
                       else
                         nil
                       end
        end



        SUPPORTED_ADAPTERS_FOR_EXPLAIN = [:postgres, :mysql2, :mysql, :sqlite]

        def explain(sql, config, explainer=nil)
          return unless explainable?
          handle_exception_in_explain do
            plan = explainer.call(config, sql)
            return process_resultset(plan, adapter) if plan
          end
        end


        def explainable?
          return false unless @explainer && is_select?(sql)

          if sql[-3,3] == '...'
            TingYun::Agent.logger.debug('Unable to collect explain plan for truncated query.')
            return false
          end

          if !SUPPORTED_ADAPTERS_FOR_EXPLAIN.include?(adapter)
            TingYun::Agent.logger.debug("Not collecting explain plan because an unknown connection adapter ('#{adapter}') was used.")
            return false
          end

          true
        end
      end
    end
  end
end
