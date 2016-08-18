# encoding: utf-8

module TingYun
  module Agent
    class Transaction
      class Exceptions
        attr_accessor :exceptions

        def initialize
          @exceptions = {}
        end

        def record_exceptions(uri, port, metric_name, attributes)
          unless @exceptions.empty?
            @exceptions.each do |exception, options|

              options[:uri]           ||= uri
              options[:port]            = port
              options[:metric_name]     = metric_name
              options[:attributes]      = attributes

              ::TingYun::Agent.instance.error_collector.notice_error(exception, options)
            end
          end
        end

        # Do not call this.  Invoke the class method instead.
        def notice_error(error, options={}) # :nodoc:
          if @exceptions[error]
            @exceptions[error].merge! options
          else
            @exceptions[error] = options
          end
        end

        #collector error
        def had_error?
          if @exceptions.empty?
            return false
          else
            return true
          end
        end
      end
    end
  end
end
