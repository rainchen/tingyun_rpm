# encoding: utf-8

require 'ting_yun/agent'

module TingYun
  module Support
    class Collector <  Struct.new :name, :port
      def to_s; "#{name}:#{port}"; end
    end

    module CollectorMethods
      def collector
        @remote_collector ||= collector_from_host
      end

      def api_collector
        @api_collector ||= Collector.new(Agent.config[:api_host], Agent.config[:api_port])
      end

      def collector_from_host(hostname=nil)
        Collector.new(hostname || Agent.config[:api_host], Agent.config[:api_port])
      end

    end

    extend CollectorMethods

  end
end
