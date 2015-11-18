# encoding: utf-8
require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/configuration/dotted_hash'

module TingYun::Configuration
  class DottedHashTest < Minitest::Test

    def test_without_nesting
      hash = DottedHash.new({ :turtle => 1 })
      assert_equal({ :turtle => 1 }, hash)
    end

    def test_with_nesting
      hash = DottedHash.new({ :turtle => { :turtle => 1 } })
      assert_equal({ :'turtle.turtle' => 1 }, hash)
    end

    def test_with_multiple_layers_of_nesting
      hash = DottedHash.new({ :turtle => { :turtle => { :turtle => 1 } } })
      assert_equal({ :'turtle.turtle.turtle' => 1 }, hash)
    end

    def test_turns_keys_to_symbols
      hash = DottedHash.new({ "turtle" => { "turtle" => { "turtle" => 1 } } })
      assert_equal({ :'turtle.turtle.turtle' => 1 }, hash)
    end

    def test_to_hash
      dotted = DottedHash.new({ "turtle" => { "turtle" => { "turtle" => 1 } } })
      hash = dotted.to_hash

      assert_instance_of(Hash, hash)
      assert_equal({ :'turtle.turtle.turtle' => 1 }, hash)
    end

    def test_option_to_keep_nesting
      hash = DottedHash.new({ :turtle => { :turtle => 1 } }, true)
      expected = {
        :turtle => { :turtle => 1},
        :'turtle.turtle' => 1,
      }

      assert_equal(expected, hash)
    end

    
  end
end
