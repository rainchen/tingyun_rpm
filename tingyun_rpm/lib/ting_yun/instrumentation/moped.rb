# encoding: utf-8

require 'ting_yun/agent'
require 'ting_yun/agent/datastore'

module TingYun
  module Instrumentation
    module Moped

      MONGODB = 'MongoDB'.freeze

      def self.included(instrumented_class)
        instrumented_class.class_eval do
          unless instrumented_class.method_defined?(:log_without_tingyun_instrumentation)
            alias_method :log_without_tingyun_instrumentation, :logging
            alias_method :logging, :log_with_tingyun_instrumentation
          end
        end
      end

      def self.instrument
        ::Moped::Node.class_eval do
          include ::TingYun::Instrumentation::Moped
        end
      end


      def log_with_tingyun_instrumentation(operations, &blk)
        operation_name, collection = determine_operation_and_collection(operations.first)
        operation = case operation_name
                      when 'INSERT'                                         then 'INSERT'
                      when 'UPDATE'                                         then 'UPDATE'
                      when 'CREATE', 'FIND_AND_MODIFY'                      then 'SAVE'
                      when 'QUERY', 'COUNT', 'GET_MORE', 'AGGREGATE'        then 'FIND'
                      else
                        nil
                    end

        res = nil
        TingYun::Agent::Datastore.wrap(MONGODB, operation, collection) do
          res = log_without_tingyun_instrumentation(operations, &blk)
        end

        res
      end

      def determine_operation_and_collection(operation)
        log_statement = operation.log_inspect.encode("UTF-8")

        collection = operation.collection if operation.respond_to?(:collection)

        operation_name = log_statement.split[0]
        if operation_name == 'COMMAND' && log_statement.include?(":mapreduce")
          operation_name = 'MAPREDUCE'
          collection = log_statement[/:mapreduce=>"([^"]+)/,1]
        elsif operation_name == 'COMMAND' && log_statement.include?(":count")
          operation_name = 'COUNT'
          collection = log_statement[/:count=>"([^"]+)/,1]
        elsif operation_name == 'COMMAND' && log_statement.include?(":aggregate")
          operation_name = 'AGGREGATE'
          collection = log_statement[/:aggregate=>"([^"]+)/,1]
        elsif operation_name == 'COMMAND' && log_statement.include?(":findAndModify")
          operation_name = 'FIND_AND_MODIFY'
          collection = log_statement[/:findAndModify=>"([^"]+)/,1]
        end
        return operation_name, collection
      end

    end
  end
end







TingYun::Support::LibraryDetection.defer do
  named :mongo_moped
  depends_on do
    defined?(::Moped)
  end

  executes do
    TingYun::Agent.logger.info 'Installing Mongo Moped instrumentation'
  end

  executes do
    ::TingYun::Instrumentation::Moped.instrument
  end
end

