# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/configuration/yaml_source'
require 'ting_yun/agent'
require 'ting_yun/configuration/dotted_hash'
require 'ting_yun/language_support'


module TingYun::Configuration
  class YamlSourceTest < Minitest::Test
    def setup
      @test_yml_path = File.expand_path(File.join(File.dirname(__FILE__),
                                                 '..','..',
                                                 'config','tingyun.yml'))
      @source = YamlSource.new(@test_yml_path, 'test')
    end


    def test_should_load_given_yaml_file
      assert_equal '127.0.0.1', @source[:api_host]
    end

    def test_should_apply_erb_transformations
      assert_equal 'heyheyhey', @source[:erb_value]
      assert_equal '', @source[:message]
      assert_equal '', @source[:license_key]
    end

    def test_config_booleans
      assert_equal true, @source[:tval]
      assert_equal false, @source[:fval]
      assert_nil @source[:not_in_yaml_val]
      assert_equal true, @source[:yval]
      assert_equal 'sure', @source[:sval]
    end

    def test_appnames
      assert_equal %w[a b c], @source[:app_name]
    end

    def test_should_load_the_config_for_the_correct_env
      refute_equal 'the.wrong.host', @source[:host]
    end

    def test_should_convert_to_dot_notation
      assert_equal 'raw', @source[:'transaction_tracer.record_sql']
    end

    def test_should_still_have_nested_hashes_around
      refute_nil @source[:transaction_tracer]
    end



    def test_should_correctly_handle_floats
      assert_equal 1.1, @source[:apdex_t]
    end



    def test_should_mark_error_on_read_as_failure
      File.stubs(:exist?).returns(true)
      File.stubs(:read).raises(StandardError.new("boo"))

      source = YamlSource.new('fake.yml', 'test')
      assert source.failed?
    end

    def test_should_mark_erb_error_as_failure
      ERB.stubs(:new).raises(StandardError.new("boo"))

      source = YamlSource.new(@test_yml_path, 'test')
      assert source.failed?
    end

    def test_should_mark_missing_section_as_failure
      source = YamlSource.new(@test_yml_path, 'yolo')
      assert source.failed?
    end

    def test_failure_should_include_message
      source = YamlSource.new(@test_yml_path, 'yolo')
      assert_includes source.failures.flatten.join(' '), 'yolo'
    end

   end
end
