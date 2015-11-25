require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/ting_yun_service/ssl'
require 'ting_yun/agent'


module TingYun
  class TingYunService
    class SslTest < Minitest::Test

      include TingYun::TingYunService::Ssl

      def setup

      end

      def test_cert_file_path
        assert_equal File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'cert', 'cacert.pem')), cert_file_path
      end

      def test_cert_file_path_uses_path_from_config
        fake_cert_path = '/certpath/cert.pem'
        with_config(:ca_bundle_path => fake_cert_path) do
          assert_equal cert_file_path, fake_cert_path
        end
      end
    end
  end
end