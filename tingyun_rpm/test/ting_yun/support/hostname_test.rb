require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/support/hostname'

module TingYun::Support
  class HostnameTest < Minitest::Test
    def setup
      Socket.stubs(:gethostname).returns('mac-ane')
    end

    def test_get_returns_socket_hostname
      assert_equal 'mac-ane', TingYun::Support::Hostname.get
    end
  end
end