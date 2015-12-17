# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','test_helper'))

require 'ting_yun/ting_yun_service'
require 'ting_yun/support/collector'
require 'ting_yun/support/serialize/json_marshaller'



module TingYun
  class TingYunServiceTest < Minitest::Test

    def setup
      @collector = TingYun::Support::Collector.new('somewhere.example.com', 30303)
      @service = TingYun::TingYunService.new('license-key',@collector)
      @http_handle = create_http_handle
      @http_handle.respond_to(:get_redirect_host, 'localhost')
      @service.stubs(:create_http_connection).returns(@http_handle)
    end

    def teardown
    end

    def create_http_handle(name='connection')
      HTTPHandle.new(name)
    end


    def test_request_timeout
      with_config(:timeout => 600) do
        service = TingYun::TingYunService.new('abcdef', @collector)
        assert_equal 600, service.request_timeout
      end
    end

    def test_license_key
      with_config(:license_key => '999') do
        service = TingYun::TingYunService.new(nil, @collector)
        assert_equal '999', service.instance_variable_get(:@license_key)
      end
      assert_equal 'license-key', @service.instance_variable_get(:@license_key)
    end

    def test_connections_not_explicitly_started_outside_session_block
      http_handle = create_http_handle
      @service.stubs(:create_http_connection).returns(http_handle)

      http_handle.respond_to(:foo, ['blah'])

      assert_equal ['blah'], @service.send(:invoke_remote, :foo, ['payload'])

      assert_equal([:request], http_handle.calls)
    end

    def test_requests_after_connection_failure_in_session_still_use_connection_caching
      conn0 = create_http_handle('first connection')
      conn1 = create_http_handle('second connection')
      conn2 = create_http_handle('third connection')
      @service.stubs(:create_http_connection).returns(conn0,conn1,conn2)
      rsp_payload = ['ok']



      conn0.respond_to(:foo, EOFError.new)
      conn1.respond_to(:foo, rsp_payload)
      conn1.respond_to(:bar, rsp_payload)
      conn1.respond_to(:baz, rsp_payload)

      @service.session do
        @service.send(:invoke_remote, :foo, ['payload'])
        @service.send(:invoke_remote, :bar, ['payload'])
        @service.send(:invoke_remote, :baz, ['payload'])
      end

      assert_equal([:start, :request, :finish], conn0.calls)
      assert_equal([:start, :request, :request, :request], conn1.calls)
      assert_equal([], conn2.calls)

      @service.close_shared_connection
      assert_equal([:start, :request, :request, :request, :finish], conn1.calls)
    end

    def test_repeated_connection_failures
      conn0 = create_http_handle('first connection')
      conn1 = create_http_handle('second connection')
      conn2 = create_http_handle('third connection')
      @service.stubs(:create_http_connection).returns(conn0, conn1, conn2)

      rsp_payload = ['ok']

      conn0.respond_to(:foo, EOFError.new)
      conn1.respond_to(:foo, EOFError.new)
      conn2.respond_to(:bar, rsp_payload)
      conn2.respond_to(:baz, rsp_payload)

      @service.session do
        assert_raises(::TingYun::Support::Exception::ServerConnectionException) do
          @service.send(:invoke_remote, :foo, ['payload'])
        end
        @service.send(:invoke_remote, :bar, ['payload'])
        @service.send(:invoke_remote, :baz, ['payload'])
      end

      assert_equal([:start, :request, :finish], conn0.calls)
      assert_equal([:start, :request, :finish], conn1.calls)
      assert_equal([:start, :request, :request], conn2.calls)
    end

    def test_repeated_twice_connection_failures
      conn0 = create_http_handle('first connection1')
      conn1 = create_http_handle('second connection1')
      conn2 = create_http_handle('third connection1')
      conn3 = create_http_handle('forth connection1')
      conn4 = create_http_handle('fifth connection1')
      conn5 = create_http_handle('sixth connection1')
      @service.stubs(:create_http_connection).returns(conn0, conn1, conn2, conn3, conn4, conn5)

      rsp_payload = ['ok']

      conn0.respond_to(:foo, EOFError.new)
      conn1.respond_to(:foo, EOFError.new)
      conn2.respond_to(:foo, rsp_payload)
      conn2.respond_to(:bar, EOFError.new)
      conn3.respond_to(:bar, rsp_payload)
      conn4.respond_to(:session, EOFError.new)
      conn5.respond_to(:session, rsp_payload)

      @service.session do
        assert_raises(::TingYun::Support::Exception::ServerConnectionException) do
          @service.send(:invoke_remote, :foo, ['payload'])
        end
      end
      assert_equal([:start, :request, :finish], conn0.calls)
      assert_equal([:start, :request, :finish], conn1.calls)
      assert_equal([], conn2.calls)

      @service.send(:invoke_remote, :bar, ['payload'])

      assert_equal([:request], conn2.calls)
      assert_equal([:request], conn3.calls)

      @service.session do
        @service.send(:invoke_remote, :session, ['payload'])
      end
      assert_equal([:start, :request, :finish], conn4.calls)
      assert_equal([:start, :request], conn5.calls)
    end

    # for PRUBY proxy compatibility
    def test_should_raise_exception_on_401
      @http_handle.reset
      @http_handle.respond_to(:getRedirectHost, 'bad license', :code => 401)
      assert_raises TingYun::Support::Exception::LicenseException do
        @service.get_redirect_host
      end
    end

    # protocol 9
    def test_should_raise_exception_on_413
      @http_handle.respond_to(:metric_data, 'too big', :code => 413)
      assert_raises TingYun::Support::Exception::UnrecoverableServerException do
        stats_hash = TingYun::Agent::Collector::StatsHash.new
        @service.metric_data(stats_hash)
      end
    end

    # protocol 9
    def test_should_raise_exception_on_415
      @http_handle.respond_to(:metric_data, 'Unsupported Media Type', :code => 415)
      assert_raises TingYun::Support::Exception::UnsupportedMediaType do
        stats_hash = TingYun::Agent::Collector::StatsHash.new
        @service.metric_data(stats_hash)
      end
    end


    def test_should_throw_received_errors
      assert_raises TingYun::Support::Exception::ServerConnectionException do
        @service.send(:invoke_remote, :bad_method)
      end
    end

    def test_should_connect_to_proxy_only_once_per_run
      conn = create_http_handle('test_should_connect_to_proxy_only_once_per_run')
      @service.stubs(:create_http_connection).returns(conn)
      conn.respond_to(:get_redirect_host, 'localhost')
      conn.respond_to(:initAgentApp, 'initagentapp')
      @service.expects(:get_redirect_host).once
      @service.connect
      conn.respond_to(:metric_data, 0)
      stats_hash = TingYun::Agent::Collector::StatsHash.new
      stats_hash.harvested_at = Time.now
      @service.stubs(:fill_metric_id_cache)
      @service.metric_data(stats_hash)
    end



    # This class acts as a stand-in for instances of Net::HTTP, which represent
    # HTTP connections.
    #
    # It can record the start / finish / request calls made to it, and exposes
    # that call sequence via the #calls accessor.
    #
    # It can also be configured to generate dummy responses for calls to request,
    # via the #respond_to method.
    class HTTPHandle
      # This module gets included into the Net::HTTPResponse subclasses that we
      # create below. We do this because the code in TingYunService switches
      # behavior based on the type of response that is returned, and we want to be
      # able to create dummy responses for testing easily.
      module HTTPResponseMock
        attr_accessor :code, :body, :message, :headers

        def initialize(body, code=200, message='OK')
          @code = code
          @body = body
          @message = message
          @headers = {}
        end

        def [](key)
          @headers[key]
        end
      end

      HTTPSuccess               = Class.new(Net::HTTPSuccess)               { include HTTPResponseMock }
      HTTPUnauthorized          = Class.new(Net::HTTPUnauthorized)          { include HTTPResponseMock }
      HTTPNotFound              = Class.new(Net::HTTPNotFound)              { include HTTPResponseMock }
      HTTPRequestEntityTooLarge = Class.new(Net::HTTPRequestEntityTooLarge) { include HTTPResponseMock }
      HTTPUnsupportedMediaType  = Class.new(Net::HTTPUnsupportedMediaType)  { include HTTPResponseMock }

      attr_accessor :read_timeout
      attr_reader :calls, :last_request

      def initialize(name)
        @name    = name
        @started = false
        reset
      end

      def start
        @calls << :start
        @started = true
      end

      def finish
        @calls << :finish
        @started = false
      end

      def inspect
        "<HTTPHandle: #{@name}>"
      end

      def started?
        @started
      end

      def address
        'whereever.com'
      end

      def port
        8080
      end

      def create_response_mock(payload, opts={})
        if TingYun::Support::Serialize::JsonMarshaller.is_supported?
          format = :json
        else
          format = :pruby
        end

        opts = {
            :code => 200,
            :format => format
        }.merge(opts)

        if opts[:code] == 401
          klass = HTTPUnauthorized
        elsif opts[:code] == 413
          klass = HTTPRequestEntityTooLarge
        elsif opts[:code] == 415
          klass = HTTPUnsupportedMediaType
        elsif opts[:code] >= 400
          klass = HTTPServerError
        else
          klass = HTTPSuccess
        end

        if opts[:format] == :json
          klass.new(JSON.dump('result' => payload), opts[:code], {})
        else
          klass.new(Marshal.dump('result' => payload), opts[:code], {})
        end
      end

      def respond_to(method, payload, opts={})
        case payload
          when Exception then rsp = payload
          else                rsp = create_response_mock(payload, opts)
        end

        @route_table[method.to_s] = rsp
      end

      def request(*args)
        @calls << :request
        request = args.first
        @last_request = request

        route = @route_table.keys.find { |r| request.path.include?(r) }

        if route
          response = @route_table[route]
          raise response if response.kind_of?(Exception)
          response
        else
          HTTPNotFound.new('not found', 404)
        end
      end

      def reset
        @calls = []
        @route_table = {}
        @last_request = nil
      end

      def last_request_payload
        return nil unless @last_request && @last_request.body

        body = @last_request.body
        content_encoding = @last_request['Content-Encoding']
        body = Zlib::Inflate.inflate(body) if content_encoding == 'deflate'

        uri = URI.parse(@last_request.path)
        params = CGI.parse(uri.query)
        format = params['marshal_format'].first
        if format == 'json'
          JSON.load(body)
        else
          Marshal.load(body)
        end
      end



    end


  end
end