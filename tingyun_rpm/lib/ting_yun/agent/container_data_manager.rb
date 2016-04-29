# encoding: utf-8
require 'ting_yun/support/exception'
require 'ting_yun/agent/collector/stats_engine'
require 'ting_yun/agent/collector/error_collector'

module TingYun
  module Agent
    module ContainerDataManager

      attr_reader :stats_engine, :error_collector, :transaction_sampler

      def drop_buffered_data
        @stats_engine.reset!
      end

      # private

      def init_containers
        @stats_engine = TingYun::Agent::Collector::StatsEngine.new
        @error_collector = TingYun::Agent::Collector::ErrorCollector.new
      end

      def container_for_endpoint(endpoint)
        case endpoint
          when :metric_data             then @stats_engine
            # type code here
        end
      end

      def transmit_data
        ::TingYun::Agent.logger.debug('Sending data to Ting Yun Service')

        @service.session do # use http keep-alive
          harvest_and_send_errors
          harvest_and_send_timeslice_data
        end
      end

      def harvest_and_send_timeslice_data
        harvest_and_send_from_container(@stats_engine, :metric_data)
      end

      def harvest_and_send_errors
        harvest_and_send_from_container(@error_collector.error_trace_array, :error_data)
      end

      # Harvests data from the given container, sends it to the named endpoint
      # on the service, and automatically merges back in upon a recoverable
      # failure.
      #
      # The given container should respond to:
      #
      #  #harvest!
      #    returns an enumerable collection of data items to be sent to the
      #    collector.
      #
      #  #reset!
      #    drop any stored data and reset to a clean state.
      #
      #  #merge!(items)
      #    merge the given items back into the internal buffer of the
      #    container, so that they may be harvested again later.
      #
      def harvest_and_send_from_container(container,endpoint)
        items = harvest_from_container(container, endpoint)
        send_data_to_endpoint(endpoint, items, container) unless items.empty?
      end

      def harvest_from_container(container, endpoint)
        items =[]
        begin
          items = container.harvest!
        rescue => e
          TingYun::Agent.logger.error("Failed to harvest #{endpoint} data, resetting. Error: ", e)
          container.reset!
        end
        items
      end

      def send_data_to_endpoint(endpoint, items, container)
        TingYun::Agent.logger.debug("Sending #{items.size} items to #{endpoint}")
        @service.send(endpoint, items)
      end

    end
  end
end
