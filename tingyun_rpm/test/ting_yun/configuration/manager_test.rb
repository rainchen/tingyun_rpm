# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/configuration/dotted_hash'
require 'ting_yun/configuration/manager'
require 'ting_yun/agent'


module TingYun::Configuration
  class ManagerTest < Minitest::Test

  	def setup
  	  @manager = Manager.new
  	end

  	def teardown
      @manager.reset_to_defaults
    end

    def test_should_use_indifferent_access
      config = DottedHash.new('string' => 'string', :symbol => 'symbol')
      @manager.add_config_for_testing(config)
      assert_equal 'string', @manager[:string]
      assert_equal 'symbol', @manager['symbol']
    end

    def test_should_apply_config_sources_in_order
      config0 = {
        :foo => 'default foo',
        :bar => 'default bar',
        :baz => 'default baz'
      }
      @manager.add_config_for_testing(config0, false)
      config1 = { :foo => 'wrong foo', :bar => 'real bar' }
      @manager.add_config_for_testing(config1)
      config2 = { :foo => 'real foo' }
      @manager.add_config_for_testing(config2)

      assert_equal 'real foo'   , @manager['foo']
      assert_equal 'real bar'   , @manager['bar']
      assert_equal 'default baz', @manager['baz']
    end

    def test_callable_value_for_config_should_return_computed_value
      source = {
        :foo          => 'bar',
        :simple_value => Proc.new { '666' },
        :reference    => Proc.new { self['foo'] }
      }
      @manager.add_config_for_testing(source)

      assert_equal 'bar', @manager[:foo]
      assert_equal '666', @manager[:simple_value]
      assert_equal 'bar', @manager[:reference]
    end

    def test_should_not_apply_removed_sources
      test_source = { :test_config_accessor => true }
      @manager.add_config_for_testing(test_source)
      @manager.remove_config(test_source)

      assert_equal nil, @manager['test_config_accessor']
    end

    def test_should_read_license_key_from_env
      ENV['TINGYUN_LICENSE_KEY'] = 'right'
      config = Manager.new
      config.add_config_for_testing({:license_key => 'wrong'}, false)
      assert_equal 'right', config[:license_key]
    ensure
      ENV.delete('TINGYUN_LICENSE_KEY')
    end

    def test_config_values_should_be_memoized
      @manager.add_config_for_testing(:setting => 'correct value')
      assert_equal 'correct value', @manager[:setting]

      @manager.instance_variable_get(:@configs_for_testing).
               unshift(:setting => 'wrong value')

      assert_equal 'correct value', @manager[:setting]
    end

    def test_dotted_hash_to_hash_is_plain_hash
      dotted = DottedHash.new({})
      assert_equal(::Hash, dotted.to_hash.class)
    end

    def test_config_is_correctly_initialized
      assert @manager.config_classes_for_testing.include?(EnvironmentSource)
      assert @manager.config_classes_for_testing.include?(DefaultSource)
      refute @manager.config_classes_for_testing.include?(YamlSource)
    end
    def test_evaluate_procs_returns_evaluated_value_if_it_responds_to_call
      callable = Proc.new { 'test' }
      assert_equal 'test', @manager.evaluate_procs(callable)
    end

    def test_evaluate_procs_returns_original_value_if_it_does_not_respond_to_call
      assert_equal 'test', @manager.evaluate_procs('test')
    end

  end
end