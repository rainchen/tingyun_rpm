require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/ting_yun_service/request'
require 'ting_yun/agent'
require 'ting_yun/support/exception'
require 'ting_yun/support/serialize/encodes'
require 'ting_yun/ting_yun_service'


class TingYun::TingYunService
  class RequestTest < Minitest::Test

    include TingYun::TingYunService::Request

    def setup

    end

    def test_check_post_size
      data = 'data'
      data.stubs(:size).returns(TingYun::Agent.config[:post_size_limit] - 1)
      assert_nil check_post_size(data)

      data.stubs(:size).returns(TingYun::Agent.config[:post_size_limit] + 1)
      assert_raises TingYun::Support::Exception::UnrecoverableServerException do
        check_post_size(data)
      end
    end

    def test_compress_request_if_needed
      data = 'data'
      data.stubs(:size).returns(64*1024 - 1)
      assert_equal [data,'identity'], compress_request_if_needed(data)

      data.stubs(:size).returns(64*1024 + 1)
      assert_equal data,  Zlib::Inflate.new.inflate(compress_request_if_needed(data)[0])
      assert_equal 'deflate',  compress_request_if_needed(data)[1]
    end

    def test_twice_send_request
      data = {:uri => "uri", :encoding => "encoding", :collector => Object, :data => "data"}
      server = Net::HTTP.new("test", 303030)


      self.stubs(:close_shared_connection).returns(nil)
      self.stubs(:http_connection).returns(server)

      expects_logging(:debug, includes('Retrying'), any_parameters)

      assert_raises TingYun::Support::Exception::ServerConnectionException do
        send_request(data)
      end

    end



  end
end