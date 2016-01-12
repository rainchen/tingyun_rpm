# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/configuration/manager'
require 'ting_yun/agent'
require 'ting_yun/configuration/yaml_source'
require 'ting_yun/configuration/server_source'


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


    def test_should_decide_by_all_config
      assert @manager[:'nbs.agent_enabled'], 'default should true, but actual is false'

      test_yml_path = File.expand_path(File.join(File.dirname(__FILE__),
                                                 '..','..',
                                                 'config','tingyun.yml'))
      yaml = YamlSource.new(test_yml_path, 'test')
      server_able = TingYun::Configuration::ServerSource.new({"config" =>{'nbs.agent_enabled' => true}})

      server_unable = TingYun::Configuration::ServerSource.new({"config" =>{'nbs.agent_enabled' => false}})
      manual  = { :'nbs.agent_enabled' => true }

      @manager.replace_or_add_config(server_unable)
      assert  !@manager[:'nbs.agent_enabled']
      @manager.replace_or_add_config(yaml)
      assert  !@manager[:'nbs.agent_enabled']
      @manager.replace_or_add_config(manual)
      assert  !@manager[:'nbs.agent_enabled']

    end

    def test_default_will_corver
      assert '', @manager[:license_key]
      with_config(:license_key => '999-999-999') do
        assert '999-999-999', @manager[:license_key]
      end
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

    def test_sources_applied_in_correct_order
      # in order of precedence
      server_source = ServerSource.new('data_report_period' => 3, 'capture_params' => true)
      manual_source = ManualSource.new(:data_report_period  => 2, :bar => 'bar', :capture_params => true)

      # load them out of order, just to prove that load order
      # doesn't determine precedence
      @manager.replace_or_add_config(manual_source)
      @manager.replace_or_add_config(server_source)

      assert_equal 2,     @manager['data_report_period']
      assert_equal 'bar', @manager['bar']
      assert_equal true, @manager['capture_params']
    end


  end
end