# encoding: utf-8
require 'ting_yun/agent'
require 'ting_yun/support/exception'

module TingYun
  module Instrumentation
    module Support
      module ExternalError
        def capture_exception(response,state)
          if response.code =~ /^[4,5][0-9][0-9]$/ && response.code!='401'
            e = TingYun::Support::Exception::InternalServerError.new("#{response.code}: #{response.message}")
            klass = "External/#{response.uri.to_s.gsub('/','%2F')}/#{state.current_transaction.remote_name}"
            e.instance_variable_set(:@klass, klass)
            e.instance_variable_set(:@external, true)
            raise e
          end
        end
      end
    end
  end
end
