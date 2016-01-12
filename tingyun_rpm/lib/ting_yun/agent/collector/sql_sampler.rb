# encoding: utf-8

module TingYun
  module Agent
    module Collector
      # This class contains the logic of recording slow SQL traces, which may
      # represent multiple aggregated SQL queries.
      #
      # A slow SQL trace consists of a collection of SQL instrumented SQL queries
      # that all normalize to the same text. For example, the following two
      # queries would be aggregated together into a single slow SQL trace:
      #
      #   SELECT * FROM table WHERE id=42
      #   SELECT * FROM table WHERE id=1234
      #
      # Each slow SQL trace keeps track of the number of times the same normalized
      # query was seen, the min, max, and total time spent executing those
      # queries, and an example backtrace from one of the aggregated queries.
      #
      class SqlSampler

        def initialize
          @samples_lock = Mutex.new
        end

        def harvest!

        end

        def reset!

        end

        def merge!

        end


      end

      class TransactionSqlData
        attr_reader :path
        attr_reader :uri
        attr_reader :sql_data
        attr_reader :guid

        def initialize
          @sql_data = []
        end
      end


    end
  end
end
