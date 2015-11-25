require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/support/system_info'


module TingYun::Support
  class SystemInfoTest < Minitest::Test

    def setup
      @sysinfo = ::TingYun::Support::SystemInfo
      @sysinfo.clear_processor_info
    end

  end
end