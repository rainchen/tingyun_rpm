# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


module TingYun
  module TingYunService
    module Connection
      # Return a Net::HTTP connection object to make a call to the collector.
      # We'll reuse the same handle for cases where we're using keep-alive, or
      # otherwise create a new one.
      def http_connection
        if @in_session
          establish_shared_connection
        else
          create_http_connection
        end
      end

      def establish_shared_connection
        unless @shared_tcp_connection
          @shared_tcp_connection = create_and_start_http_connection
        end
        @shared_tcp_connection
      end


      def create_and_start_http_connection
        conn = create_http_connection
        start_connection(conn)
        conn
      end

      def start_connection(conn)
        Agent.logger.debug("Opening TCP connection to #{conn.address}:#{conn.port}")
        TingYun::Support::TimerLib.timeout(@request_timeout) { conn.start }
        conn
      end


      def create_http_connection
        if Agent.config[:proxy_host]
          Agent.logger.debug("Using proxy server #{Agent.config[:proxy_host]}:#{Agent.config[:proxy_port]}")

          proxy = Net::HTTP::Proxy(
              Agent.config[:proxy_host],
              Agent.config[:proxy_port],
              Agent.config[:proxy_user],
              Agent.config[:proxy_pass]
          )
          conn = proxy.new(@collector.name, @collector.port)
        else
          conn = Net::HTTP.new(@collector.name, @collector.port)
        end

        setup_connection_for_ssl(conn) if Agent.config[:ssl]
        setup_connection_timeouts(conn)
        Agent.logger.debug("Created net/http handle to #{conn.address}:#{conn.port}")

        conn
      end

      def close_shared_connection
        if @shared_tcp_connection
          Agent.logger.debug("Closing shared TCP connection to #{@shared_tcp_connection.address}:#{@shared_tcp_connection.port}")
          @shared_tcp_connection.finish if @shared_tcp_connection.started?
          @shared_tcp_connection = nil
        end
      end


      def setup_connection_timeouts(conn)
        # We use Timeout explicitly instead of this
        conn.read_timeout = nil

        if conn.respond_to?(:keep_alive_timeout) && Agent.config[:aggressive_keepalive]
          conn.keep_alive_timeout = Agent.config[:keep_alive_timeout]
        end
      end
    end
  end
end