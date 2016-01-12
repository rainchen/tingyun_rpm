require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper'))
require 'ting_yun/support/serialize/json_marshaller'

module TingYun::Support::Serialize
  class JsonMarshallerTest < Minitest::Test

    def setup
     @json_marshaller = TingYun::Support::Serialize::JsonMarshaller.new
    end


    def test_json_marshaller_logs_on_empty_response_from_collector
      expects_logging(:error, includes('Empty'), any_parameters)
      assert_nil @json_marshaller.load('')
    end

    def test_json_marshaller_logs_on_nil_response_from_collector
      expects_logging(:error, includes('Empty'), any_parameters)
      assert_nil @json_marshaller.load(nil)
    end

  end
end