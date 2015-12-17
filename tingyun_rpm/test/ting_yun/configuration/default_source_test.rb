# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/configuration/default_source'

module TingYun::Configuration
  class DefaultSourceTest < Minitest::Test

    def setup
      @default_source = DefaultSource.new
      @defaults = ::TingYun::Configuration::DEFAULTS
    end

    def test_agent_enable
       @defaults[:'nbs.agent_enabled']
    end

    def test_default_values_have_a_public_setting
      @defaults.each do |config_setting, config_value|
        refute_nil config_value[:public], "Config setting: #{config_setting}"
      end
    end

    def test_default_values_have_types
      @defaults.each do |config_setting, config_value|
        refute_nil config_value[:type], "Config setting: #{config_setting}"
      end
    end

    def test_default_values_have_descriptions
      @defaults.each do |config_setting, config_value|
        refute_nil config_value[:description]
        assert config_value[:description].length > 0, "Config setting: #{config_setting}"
      end
    end

    def test_declared_types_match_default_values
      ::TingYun::Frameworks.framework.local_env.stubs(:discovered_dispatcher).returns(:unicorn)

      @default_source.keys.each do |key|
        actual_type = get_config_value_class(fetch_config_value(key))
        expected_type = @defaults[key][:type]

        if @defaults[key][:allow_nil]
          assert [NilClass, expected_type].include?(actual_type), "Default value for #{key} should be NilClass or #{expected_type}, is #{actual_type}."
        else
          assert_equal expected_type, actual_type, "Default value for #{key} should be #{expected_type}, is #{actual_type}."
        end
      end
    end

    def test_default_values_maps_keys_to_their_default_values
      default_values = @default_source.default_values

      @defaults.each do |key, value|
        assert_equal value[:default], default_values[key]
      end
    end
    
    def fetch_config_value(key)
      accessor = key.to_sym
      config = @default_source

      if config.has_key?(accessor)
        if config[accessor].respond_to?(:call)
            value = config[accessor]

            while value.respond_to?(:call)
              value = config.instance_eval(&value)
            end

            return value
        else
          return config[accessor]
        end
      end
      nil
    end

    def get_config_value_class(value)
      type = value.class

      if type == TrueClass || type == FalseClass
        Boolean
      else
        type
      end
    end

    def test_framework_is_test
      assert_equal :test, DefaultSource.framework.call
    end

    def test_config_search_paths_with_home
      with_environment("HOME" => "/home") do
        paths = DefaultSource.config_search_paths.call()
        assert_includes paths, "/home/.tingyun/tingyun.yml"
        assert_includes paths, "/home/tingyun.yml"
      end
    end

    def test_config_search_path_in_warbler
      with_environment("GEM_HOME" => "/some/path.jar!") do
        assert_includes DefaultSource.config_search_paths.call(), "/some/path.jar!/path/config/tingyun.yml"
      end
    end

    def test_all_settings_specify_whether_they_are_allowed_from_server
      unspecified_keys = []
      bad_value_keys = []

      @defaults.each do |key, spec|
        if !spec.has_key?(:allowed_from_server)
          unspecified_keys << key
        end

        if ![true, false].include?(spec[:allowed_from_server])
          bad_value_keys << key
        end

        assert unspecified_keys.empty?, "The following keys did not specify a value for :allowed_from_server: #{unspecified_keys.join(', ')}"
        assert bad_value_keys.empty?, "The following keys had incorrect :allowed_from_server values (only true or false are allowed): #{bad_value_keys.join(', ')}"
      end
    end
  end
end
