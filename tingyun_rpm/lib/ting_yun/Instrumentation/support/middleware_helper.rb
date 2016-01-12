# encoding: utf-8

module TingYun
  module Instrumentation
    module Support
      module MiddlewareHelper
        class TransactionName


          def self.prefix_for_category(category = nil)

            case category
              when :controller then ::TingYun::Agent::Transaction::CONTROLLER_PREFIX
              when :task       then ::TingYun::Agent::Transaction::TASK_PREFIX
              when :rack       then ::TingYun::Agent::Transaction::RACK_PREFIX
              when :uri        then ::TingYun::Agent::Transaction::CONTROLLER_PREFIX
              when :sinatra    then ::TingYun::Agent::Transaction::SINATRA_PREFIX
              when :middleware then ::TingYun::Agent::Transaction::MIDDLEWARE_PREFIX
              when :grape      then ::TingYun::Agent::Transaction::GRAPE_PREFIX
              when :rake       then ::TingYun::Agent::Transaction::RAKE_PREFIX
              else "#{category.to_s}/" # for internal use only
            end
          end
        end
      end
    end

  end
end
