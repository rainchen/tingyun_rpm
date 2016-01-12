# encoding: utf-8

# A Hash-like class for storing errorTraceData data.
#

require 'ting_yun/support/exception'

module TingYun
  module Agent
    module Collector
      class NoticedError

        attr_accessor :path, :timestamp, :message, :exception_class_name,
                      :request_uri, :request_port, :file_name, :line_number,
                      :stack_trace, :attributes_from_notice_error, :attributes,
                      :http_code

        attr_reader   :exception_id, :is_internal


        def initialize(path, exception, timestamp = Time.now)
          @exception_id = exception.object_id
          @path = path
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
      end
    end
  end
end

