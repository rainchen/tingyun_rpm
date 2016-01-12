# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','test_helper'))

require 'ting_yun/frameworks'

module TingYun
  class FrameworksTest < Minitest::Test

    def setup
      @framework = ::TingYun::Frameworks::Framework.instance
    end

    def test_framework
      framework = ::TingYun::Frameworks.framework
      assert_kind_of TingYun::Frameworks::Test, framework

    end


  end
end
