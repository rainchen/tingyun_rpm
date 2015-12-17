# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/configuration/default_source'
require 'ting_yun/configuration/server_source'
require 'ting_yun/agent'


module TingYun::Configuration
  class ServerSourceTest < Minitest::Test
  	
    def setup
      ServerSource.add_top_level_keys_for_testing([:TOP_LEVEL_KEYS,:other,:another,:daemon_debug,:dispatcher])
      config = {
      	:agent_log_file_name => true,
      	:daemon_debug        => true,
      	:wrong               => true,
      	:TOP_LEVEL_KEYS      => true,
      	:dispatcher          => 'dispatcher'
      }
      @source = ServerSource.new(config)
    end

    def teardown
      ServerSource.remove_top_level_keys_for_testing([:TOP_LEVEL_KEYS,:other,:another,:daemon_debug,:dispatcher])
    end


    def test_initialize
      	assert_equal [:daemon_debug] ,@source.keys.find_all {|key| ServerSource::TOP_LEVEL_KEYS.include?(key) }
    end
    def test_server_corver_default_value
        TingYun::Agent.config.replace_or_add_config(@source)
        assert TingYun::Agent.config[:daemon_debug],TingYun::Agent.config[:daemon_debug].to_s
    end
  end
end
