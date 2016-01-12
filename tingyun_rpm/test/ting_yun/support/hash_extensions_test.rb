require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/support/hash_extensions'

module TingYun::Support
  class HashExtensionsTest < Minitest::Test

    def test_stringify_keys_in_object_with_nested_hash
      hash = {:foo => {:bar => [{:baz => "qux"}, "quux"]}}
      expected = {"foo" => {"bar" => [{"baz" => "qux"}, "quux"]}}

      actual = TingYun::Support::HashExtensions.stringify_keys_in_object(hash)

      assert_equal expected, actual
    end

    def test_stringify_keys_in_object_with_array
      array = ["foo", {:bar => [{:baz => "qux"}, "quux"]}]
      expected = ["foo", {"bar" => [{"baz" => "qux"}, "quux"]}]

      actual = TingYun::Support::HashExtensions.stringify_keys_in_object(array)

      assert_equal expected, actual
    end

    def test_stringify_keys_in_object_does_not_mutate_argument
      arg = {:foo => "bar"}
      result = TingYun::Support::HashExtensions.stringify_keys_in_object(arg)
      refute_same arg, result
      assert_includes arg.keys, :foo
    end

  end
end