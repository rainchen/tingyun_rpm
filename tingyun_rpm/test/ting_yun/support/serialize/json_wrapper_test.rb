require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper'))
require 'ting_yun/support/serialize/json_wrapper'

module TingYun::Support::Serialize
  class  JSONWrapperTest < Minitest::Test

    def setup
    end
    def test_json_round_trip
      obj = [
          99, 'luftballons',
          {
              'Hast du etwas' => 'Zeit für mich',
              'Dann singe ich' => {
                  'ein lied' => 'für dich'
              }
          }
      ]
      assert_equal obj,::TingYun::Support::Serialize::JSONWrapper.load( ::TingYun::Support::Serialize::JSONWrapper.dump(obj) )
    end


    if TingYun::Support::LanguageSupport.supports_string_encodings?
      def test_normalizes_string_encodings_if_asked
        string = (0..255).to_a.pack("C*")
        encoded = ::TingYun::Support::Serialize::JSONWrapper.dump([string], :normalize => true)
        decoded = ::TingYun::Support::Serialize::JSONWrapper.load(encoded)
        expected = [string.dup.force_encoding('ISO-8859-1').encode('UTF-8')]
        assert_equal(expected, decoded)
      end
    end


  end
end