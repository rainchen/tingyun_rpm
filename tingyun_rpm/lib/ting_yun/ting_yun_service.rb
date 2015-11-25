# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


require 'ting_yun/agent'
require 'zlib'
require 'ting_yun/ting_yun_service/http'
require 'ting_yun/support/collector'
require 'ting_yun/support/serialize/encodes'
require 'ting_yun/support/timer_lib'
require 'ting_yun/support/exception'
require 'ting_yun/support/serialize/json_marshaller'

module TingYun
  class TingYunService
    include Http

    CONNECTION_ERRORS = [Timeout::Error, EOFError, SystemCallError, SocketError].freeze

    PROTOCOL_VERSION = 1

    DATA_COLLECTOR = "redirect.networkbench.com".freeze

    attr_accessor :request_timeout, :ting_yun_id_secret, :app_session_key, :data_version

    def initialize(license_key=nil,collector=TingYun::Support.collector)
      @license_key = license_key || TingYun::Agent.config[:license_key]
      @request_timeout = TingYun::Agent.config[:timeout]
      @collector = collector
      @ting_yun_id_secret = nil
      @ssl_cert_store = nil
      @shared_tcp_connection = nil
      @data_version = nil
      @marshaller =TingYun::Support::Serialize::JsonMarshaller.new
    end

    def connect(setting={})
      if host = get_redirect_host
        @collector = TingYun::Support.collector_from_host(host)
      end
      response = invoke_remote(:connect, [settings])
      @agent_id = response['agent_run_id']
      response
    end

    def init_agent_app
      invoke_remote(:initAgentApp)
    end

    def get_redirect_host
      invoke_remote(:getRedirectHost)
    end

    def force_restart
      close_shared_connection
    end

    # send a message via post to the actual server. This attempts
    # to automatically compress the data via zlib if it is large
    # enough to be worth compressing, and handles any errors the
    # server may return

    private

    def invoke_remote(method, payload = [], options = {})
      start_time = Time.now

      data, size, serialize_finish_time = nil
      begin
        data = @marshaller.(payload, options)
      rescue StandardError, SystemStackError => e
        handle_serialization_error(method, e)
      end
      serialize_finish_time = Time.now

      data, encoding = compress_request_if_needed(data)
      size = data.size

      uri = remote_method_uri(method)

      response = send_request(:data      => data,
                              :uri       => uri,
                              :encoding  => encoding,
                              :collector => @collector)
    ensure

    end

    def handle_serialization_error(method, e)
      msg = "Failed to serialize #{method} data using #{@marshaller.class.to_s}: #{e.inspect}"
      error = SerializationError.new(msg)
      error.set_backtrace(e.backtrace)
      raise error
    end





  end
end