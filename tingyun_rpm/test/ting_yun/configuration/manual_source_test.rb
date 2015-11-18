# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/configuration/manual_source'

module TingYun::Configuration
  class ManualSourceTest < Minitest::Test
    def test_prepopulates_nested_keys
      source = ManualSource.new({ :outer => { :inner => "stuff" } })
      expected = {
        :outer => { :inner => "stuff" },
        :'outer.inner' => "stuff"
      }
      assert_equal(expected, source)
    end
  end
end
