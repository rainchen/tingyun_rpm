# encoding: utf-8

# A Hash-like class for storing errorTraceData data.
#

require 'ting_yun/support/exception'
require 'ting_yun/support/coerce'


module TingYun
  module Agent
    module Collector
      class NoticedError

        attr_accessor :metric_name, :timestamp, :message, :exception_class_name,
                      :request_uri, :request_port, :file_name, :line_number,
                      :stack_trace, :attributes_from_notice_error, :attributes,
                      :count_error, :thread_name, :external_error?, :external_metric_name


        attr_reader :exception_id, :is_internal


        def initialize(metric_name, exception, timestamp = Time.now)
          @stack_trace = []
          @count_error = 1
          @exception_id = exception.object_id
          @metric_name = metric_name
          @timestamp = timestamp
          @exception_class_name = exception.is_a?(Exception) ? exception.class.name : 'Error'

          # It's critical that we not hold onto the exception class constant in this
          # class. These objects get serialized for Resque to a process that might
          # not have the original exception class loaded, so do all processing now
          # while we have the actual exception!
          @is_internal = (exception.class < TingYun::Support::Exception::InternalAgentError)

          if exception.nil?
            @message = '<no message>'
          elsif exception.respond_to?('original_exception')
            @message = (exception.original_exception || exception).to_s
          else # exception is not nil, but does not respond to original_exception
            @message = exception.to_s
          end


          unless @message.is_a?(String)
            # In pre-1.9.3, Exception.new({}).to_s.class != String
            # That is, Exception#to_s may not return a String instance if one wasn't
            # passed in upon creation of the Exception. So, try to generate a useful
            # String representation of the exception message, falling back to failsafe
            @message = String(@message.inspect) rescue '<unknown message type>'
          end

          # clamp long messages to 4k so that we don't send a lot of
          # overhead across the wire
          @message = @message[0..4095] if @message.length > 4096
        end


        def ==(other)
          if other.respond_to?(:exception_id)
            exception_id == other.exception_id
          else
            false
          end
        end

        include TingYun::Support::Coerce

        def to_collector_array(encoder)
          if  external_error?
            [timestamp.to_i,
             string(external_metric_name),
             int(attributes.agent_attributes[:httpStatus]),
             string(exception_class_name),
             count_error,
             string(metric_name),
             encoder.encode(error_params)
            ]
          else
            [timestamp.to_i,
             string(metric_name),
             int(attributes.agent_attributes[:httpStatus]),
             string(exception_class_name),
             string(message),
             count_error,
             string(request_uri),
             encoder.encode(error_params)
            ]
          end
        end

        def error_params
          {
              :params => custom_params,
              :requestParams => request_params,
              :stacktrace => stack_trace
          }
        end

        def custom_params
          {
              :threadName => string(attributes.agent_attributes[:threadName]),
              :httpStatus => int(attributes.agent_attributes[:httpStatus]),
              :referer    => string(attributes.agent_attributes[:referer]) || ''
          }
        end

        def request_params
          attributes.agent_attributes[:request_params]
        end

      end
    end
  end
end

