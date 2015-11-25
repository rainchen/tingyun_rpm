require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/ting_yun_service/http'


class TingYun::TingYunService
  class HttpTest < Minitest::Test

    include TingYun::TingYunService::Http

    def setup

    end

    def test_uri_with_sym_method
      @license_key     = "123"
      @app_session_key = "456"
      @data_version    = "789"

      assert_equal "test?licenseKey=123&appSessionKey=456&version=789" ,remote_method_uri(:test)
    end

    def test_uri_with_string_method
      @license_key     = "123"
      @app_session_key = "456"
      @data_version    = "789"

      assert_equal "test?licenseKey=123&appSessionKey=456&version=789" ,remote_method_uri("test")
    end

    def test_uri_with_nil
      @license_key     = "123"
      @app_session_key = "456"
      @data_version    = "789"

      assert_equal "?licenseKey=123&appSessionKey=456&version=789" ,remote_method_uri(nil)
    end
  end
end