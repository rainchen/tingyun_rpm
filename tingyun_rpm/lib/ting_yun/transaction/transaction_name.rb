# encoding: utf-8
require 'ting_yun/constants'

module TingYun
  module Agent
    class TransactionName
      def self.prefix_for_category(category = nil)
        case category
          when :controller then TingYun::Constants::WEB_TRANSACTION_PREFIX
          when :task       then TingYun::Constants::TASK_PREFIX
          when :rack       then TingYun::Constants::RACK_PREFIX
          when :uri        then TingYun::Constants::WEB_TRANSACTION_PREFIX
          when :sinatra    then TingYun::Constants::SINATRA_PREFIX
          when :middleware then TingYun::Constants::MIDDLEWARE_PREFIX
          when :grape      then TingYun::Constants::GRAPE_PREFIX
          else "#{category.to_s}/" # for internal use only
        end
      end
    end
  end
end
