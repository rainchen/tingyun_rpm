# encoding: utf-8

require 'forwardable'

module TingYun
  module Agent
    class TransactionTimings

      class Timings <  Struct.new :sql_duration, :external_duration, :rds_duration, :mc_duration, :mon_duration; end

      def initialize(queue_time_in_seconds, start_time_in_seconds, transaction_name, trace_id)
        @now = Time.now.to_f
        @queue_time_in_seconds = clamp_to_positive(queue_time_in_seconds.to_f)
        @start_time_in_seconds = clamp_to_positive(start_time_in_seconds.to_f)

        @transaction_name = transaction_name
        @trace_id = trace_id
        @timings = TingYun::Agent::TransactionTimings::Timings.new
      end


      attr_reader :transaction_name,
                  :start_time_in_seconds, :queue_time_in_seconds, :trace_id, :timings

      extend Forwardable

      def_delegators :@timings, :sql_duration, :sql_duration= ,
                     :external_duration, :external_duration=,
                     :rds_duration, :rds_duration=,
                     :mc_duration, :mc_duration=,
                     :mon_duration, :mon_duration=

      def transaction_name_or_unknown
        transaction_name || ::TingYun::Agent::UNKNOWN_METRIC
      end

      def start_time_as_time
        Time.at(@start_time_in_seconds)
      end

      def start_time_in_millis
        convert_to_milliseconds(@start_time_in_seconds)
      end

      def queue_time_in_millis
        convert_to_milliseconds(queue_time_in_seconds)
      end

      def app_time_in_millis
        convert_to_milliseconds(app_time_in_seconds)
      end

      def app_time_in_seconds
        @now - @start_time_in_seconds
      end

      def app_execute_duration
        app_time_in_millis - queue_time_in_millis - (sql_duration||0 ) - (external_duration||0) - (rds_duration||0) - (mon_duration||0) - (mc_duration||0)
      end

      # Helpers

      def convert_to_milliseconds(value_in_seconds)
        clamp_to_positive((value_in_seconds.to_f * 1000.0).round)
      end

      def clamp_to_positive(value)
        return 0.0 if value < 0.0
        value
      end

    end
  end
end