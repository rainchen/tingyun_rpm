# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','test_helper'))

require 'ting_yun/ting_yun_service'
require 'ting_yun/support/collector'
require 'ting_yun/support/serialize/json_marshaller'



module TingYun
  class TingYunServiceTest < Minitest::Test

    def setup
      @collector = TingYun::Support::Collector.new('somewhere.example.com', 30303)
      @service = TingYun::TingYunService.new('license-key',@collector)
    end

    def teardown
    end

    def test_request_timeout
      with_config(:timeout => 600) do
        service = TingYun::TingYunService.new('abcdef', @server)
        assert_equal 600, service.request_timeout
      end
    end




  end
end