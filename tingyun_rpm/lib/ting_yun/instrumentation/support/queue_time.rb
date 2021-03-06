# encoding: utf-8

module TingYun
  module Instrumentation
    module Support

      module QueueTime
        unless defined?(REQUEST_START_HEADER)
          REQUEST_START_HEADER = 'HTTP_X_REQUEST_START'.freeze
          QUEUE_START_HEADER = 'HTTP_X_QUEUE_START'.freeze
          X_QUEUE_START           = 'X-QUEUE-START'.freeze
          MIDDLEWARE_START_HEADER = 'HTTP_X_MIDDLEWARE_START'.freeze
          ALL_QUEUE_METRIC = 'WebFrontend/QueueTime'.freeze
          # any timestamps before this are thrown out and the parser
          # will try again with a larger unit (2000/1/1 UTC)
          EARLIEST_ACCEPTABLE_TIME = Time.at(946684800)

          CANDIDATE_HEADERS = [
              REQUEST_START_HEADER,
              QUEUE_START_HEADER,
              X_QUEUE_START,
              MIDDLEWARE_START_HEADER
          ].freeze

          DIVISORS = [1_000_000, 1_000, 1]
        end

        module_function

        def parse_frontend_timestamp(headers, now=Time.now)
          earliest = nil

          CANDIDATE_HEADERS.each do |header|
            if headers[header]
              parsed = parse_timestamp(timestamp_string_from_header_value(headers[header]))
              if parsed && (!earliest || parsed < earliest)
                earliest = parsed
              end
            end
          end

          if earliest && earliest > now
            TingYun::Agent.logger.debug("Negative queue time detected, treating as zero: start=#{earliest.to_f} > now=#{now.to_f}")
            earliest = now
          end

          earliest
        end

        def timestamp_string_from_header_value(value)
          case value
            when /^\s*([\d+\.]+)\s*$/ then
              $1
            # following regexp intentionally unanchored to handle
            # (ie ignore) leading server names
            when /t=([\d+\.]+)/ then
              $1
          end
        end

        def parse_timestamp(string)
          DIVISORS.each do |divisor|
            begin
              t = Time.at(string.to_f / divisor)
              return t if t > EARLIEST_ACCEPTABLE_TIME
            rescue RangeError
              # On Ruby versions built with a 32-bit time_t, attempting to
              # instantiate a Time object in the far future raises a RangeError,
              # in which case we know we've chosen the wrong divisor.
            end
          end

          nil
        end
      end
    end
  end
end
