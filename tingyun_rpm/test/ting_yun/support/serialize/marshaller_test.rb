require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper'))


require 'ting_yun/support/serialize/marshaller'
require 'ting_yun/support/serialize/encodes'
require 'ting_yun/support/exception'

module TingYun::Support::Serialize
  class MarshallerTest < Minitest::Test

    def setup
      @marshaller = TingYun::Support::Serialize::Marshaller.new
    end


    def test_marshaller_obeys_requested_encoder
      dummy = ['hello there']
      def dummy.to_collector_array(encoder)
        self.map { |x| encoder.encode(x) }
      end
      identity_encoder = TingYun::Support::Serialize::Encoders::Identity

      prepared = @marshaller.prepare(dummy, :encoder => identity_encoder)

      assert_equal(dummy, prepared)

      prepared = @marshaller.prepare(dummy, :encoder => ReverseEncoder)
      decoded = prepared.map { |x| x.reverse }
      assert_equal(dummy, decoded)
    end

    def test_marshaller_prepare_passes_on_options
      inner_array = ['abcd']
      def inner_array.to_collector_array(encoder)
        self.map { |x| encoder.encode(x) }
      end
      dummy = [[inner_array]]
      prepared = @marshaller.prepare(dummy, :encoder => ReverseEncoder)
      assert_equal([[['dcba']]], prepared)
    end



    def test_return_value_data_no_has_key?
      expects_logging(:debug, includes("Unexpected response"), any_parameters)
      assert_nil @marshaller.return_value_for_testing("string"),'should be nil if respond_to?(:has_key?)==false'
    end

    def test_return_value_data_no_exception_return_value
      expects_logging(:debug, includes("Unexpected response"), any_parameters)
      assert_nil @marshaller.return_value_for_testing({:str => "has_key?"}),'should be nil if have no "return_value and exception" '
    end


    def test_return_value_data_and_return_value
      assert 'return_value', @marshaller.return_value_for_testing({'return_value' => 'return_value'})
    end


    module ReverseEncoder
      def self.encode(data)
        data.reverse
      end
    end

  end
end