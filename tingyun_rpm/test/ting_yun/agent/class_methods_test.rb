# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/configuration/manager'
require 'ting_yun/agent/class_methods'




module TingYun
  module Agent
    class ClassMethodsTest < MiniTest::Test
      include ClassMethods
      def setup
      end

      def teardown

      end

      def test_config
          config.must_be_instance_of ::TingYun::Configuration::Manager
      end

    end
  end
end