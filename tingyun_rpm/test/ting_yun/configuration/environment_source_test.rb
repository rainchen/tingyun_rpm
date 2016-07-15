# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/configuration/environment_source'
require 'ting_yun/configuration/default_source'

module TingYun::Configuration
  class EnvironmentSourceTest < Minitest::Test

    def setup
      @original_env = {}
      @original_env.replace(ENV)
      @environment_source = EnvironmentSource.new
    end

    def teardown
      ENV.replace(@original_env)
    end

    def test_environment_strings_are_applied
      assert_applied_string 'NRCONFIG', 'config_path'
      assert_applied_string 'TING_YUN_LICENSE_KEY', 'license_key'
      assert_applied_string 'TINGYUN_LICENSE_KEY', 'license_key'
      assert_applied_string 'TING_YUN_APP_NAME', 'app_name'
      assert_applied_string 'TINGYUN_APP_NAME', 'app_name'
      assert_applied_string 'TING_YUN_HOST', 'host'
    end

    def test_environment_fixnums_are_applied
      assert_applied_fixnum 'TING_YUN_PORT', 'port'
    end

    def test_environment_symbols_are_applied
      assert_applied_symbol 'TING_YUN_DISPATCHER', 'dispatcher'
      assert_applied_symbol 'TINGYUN_DISPATCHER', 'dispatcher'
      assert_applied_symbol 'TING_YUN_FRAMEWORK', 'framework'
      assert_applied_symbol 'TINGYUN_FRAMEWORK', 'framework'
    end

    def test_set_log_config_from_environment
      ENV['TING_YUN_LOG'] = 'off/in/space.log'
      source = EnvironmentSource.new
      assert_equal 'off/in', source[:log_file_path]
      assert_equal 'space.log', source[:log_file_name]
    end

    def test_set_log_config_STDOUT_from_environment
      ENV['TING_YUN_LOG'] = 'STDOUT'
      source = EnvironmentSource.new
      assert_equal 'STDOUT', source[:log_file_name]
      assert_equal 'STDOUT', source[:log_file_path]
    end

    def test_set_values_from_ting_yun_environment_variables
      keys = %w(TING_YUN_LICENSE_KEY TINGYUN_CONFIG_PATH)
      keys.each { |key| ENV[key] = 'skywizards' }

      expected_source = EnvironmentSource.new

      [:license_key, :config_path].each do |key|
        assert_equal 'skywizards', expected_source[key]
      end
    end


    def test_set_value_from_environment_variable
      ENV['TING_YUN_LICENSE_KEY'] = 'super rad'
      @environment_source.set_value_from_environment_variable('TING_YUN_LICENSE_KEY')
      assert_equal @environment_source[:license_key], 'super rad'
    end

    def test_set_key_by_type_uses_the_default_type
      ENV['TING_YUN_TEST'] = 'true'
      @environment_source.set_key_by_type(:'nbs.agent_enabled', 'TING_YUN_TEST')
      assert_equal true, @environment_source[:'nbs.agent_enabled']
    end

    def test_set_key_with_ting_yun_prefix
      assert_applied_string('TING_YUN_LICENSE_KEY', :license_key)
    end

    def test_set_key_with_tingyun_prefix
      assert_applied_string('TINGYUN_LICENSE_KEY', :license_key)
    end

    def test_does_not_set_key_without_ting_yun_related_prefix
      ENV['CONFIG_PATH'] = 'boom'
      refute_equal 'boom', EnvironmentSource.new[:config_path]
    end

    def test_convert_environment_key_to_config_key
      result = @environment_source.convert_environment_key_to_config_key('TINGYUN_IS_RAD')
      assert_equal :is_rad, result
    end

    def test_convert_environment_key_to_config_key_respects_aliases
      assert_applied_boolean('TINGYUN_NBS.AGENT_ENABLED', :'nbs.agent_enabled')
    end

    def test_convert_environment_key_to_config_key_allows_underscores_as_dots
      assert_applied_string('TING_YUN_RUM.SCRIPT', :'rum.script')
    end



    def assert_applied_string(env_var, config_var)
      ENV[env_var] = 'test value'
      assert_equal 'test value', EnvironmentSource.new[config_var.to_sym]
      ENV.delete(env_var)
    end

    def assert_applied_symbol(env_var, config_var)
      ENV[env_var] = 'test value'
      assert_equal :'test value', EnvironmentSource.new[config_var.to_sym]
      ENV.delete(env_var)
    end

    def assert_applied_fixnum(env_var, config_var)
      ENV[env_var] = '3000'
      assert_equal 3000, EnvironmentSource.new[config_var.to_sym]
      ENV.delete(env_var)
    end

    def assert_applied_boolean(env_var, config_var)
      ENV[env_var] = 'true'
      assert_equal true, EnvironmentSource.new[config_var.to_sym]
      ENV.delete(env_var)
    end

  end
end
