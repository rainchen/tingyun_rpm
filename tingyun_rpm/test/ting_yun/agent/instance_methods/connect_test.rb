# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper'))
require 'ting_yun/agent/instance_methods/connect'
require 'ting_yun/agent'
require 'ting_yun/ting_yun_service'
require 'ting_yun/configuration/server_source'
require 'ting_yun/support/exception'
require 'ting_yun/frameworks'


class TingYun::Agent::InstanceMethods::ConnectTest < MiniTest::Test

  include TingYun::Agent::InstanceMethods::Connect

  def setup
    @connect_attempts = 0
    @connect_state = nil
    @connected = nil
    @local_host = nil
    collector = TingYun::Support::Collector.new('localhost', 30303)
    @service = TingYun::TingYunService.new('abcdef', collector)
  end

  def local_host
    @local_host
  end

  def test_should_connect_if_pending
    @connect_state = :pending
    assert(should_connect?, "should attempt to connect if pending")
  end

  def test_should_not_connect_if_disconnected
    @connect_state = :disconnected
    assert(!should_connect?, "should not attempt to connect if force disconnected")
  end

  def test_should_not_connect_if_connected
    @connect_state = :connected
    assert(!should_connect?, "should not attempt to connect if force disconnected")
  end

  def test_should_connect_if_forced
    @connect_state = :disconnected
    assert(should_connect?(true), "should connect if forced")
    @connect_state = :connected
    assert(should_connect?(true), "should connect if forced")
    @connect_state = :pending
    assert(should_connect?(true), "should connect if forced")
  end

  def test_increment_retry_period
    10.times do |i|
      assert_equal((i * 60), connect_retry_period)
      note_connect_failure
    end
    assert_equal(600, connect_retry_period)
  end

  def test_disconnect
    assert disconnect
  end

  def test_connect_settings_have_environment_report
     generate_environment_report
    assert connect_settings[:env].detect{ |(k, _)|
             k == 'Gems'
           }, "expected connect_settings to include gems from environment"
  end

  def test_environment_for_connect_negative
    with_config(:send_environment_info => false) do
      generate_environment_report
      assert_equal Hash.new, connect_settings[:env]
    end
  end

  def test_connect_settings
    with_config(:app_names => 'apps') do
      TingYun::Agent.config.expects(:app_names).returns(["apps"])
      @local_host = "lo-calhost"
      @environment_report = {}
      keys = %w(pid host appName language agentVersion env).map(&:to_sym)
      settings = connect_settings
      keys.each do |k|
        assert_includes(settings.keys, k)
        refute_nil(settings[k], "expected a value for #{k}")
      end
    end
  end
  def test_query_server_for_configuration
    self.expects(:connect_to_server).returns("so happy")
    self.expects(:finish_setup).with("so happy")
    query_server_for_configuration
  end

  def test_finish_setup
    TingYun::Configuration::ServerSource.add_top_level_keys_for_testing([:daemon_debug])
    config = {:daemon_debug => true}
    finish_setup(config)
    assert(::TingYun::Agent.config[:daemon_debug],"should daemon_debug to be true")
    assert_kind_of TingYun::Configuration::ServerSource, TingYun::Agent.config.source(:daemon_debug)
    TingYun::Configuration::ServerSource.remove_top_level_keys_for_testing([:daemon_debug])
    ::TingYun::Agent.config.reset_to_defaults
  end

  def test_keep_retrying_or_force_reconnect?
    @connect_state = :unknown

    catch_errors do
      raise TingYun::Support::Exception::ForceDisconnectException.new("raise a ForceDisconnectException ")
    end
    assert_equal :disconnected, @connect_state
    @connect_state = :unknown
    catch_errors do
      raise TingYun::Support::Exception::LicenseException.new("raise a LicenseException ")
    end
    assert_equal :disconnected, @connect_state

    @connect_state = :unknown
    catch_errors do
      raise TingYun::Support::Exception::UnrecoverableAgentException.new("raise a UnrecoverableAgentException ")
    end
    assert_equal :disconnected, @connect_state

  end
  def drop_buffered_data

  end

  def shutdown
    @shutdown = true
  end

  def test_handle_force_disconnect
    error = mock(:message => 'a message')

    self.expects(:disconnect)
    handle_force_disconnect(error)
  end

  def test_handle_other_error
    error = StandardError.new('a message')

    self.expects(:disconnect)
    handle_other_error(error)
  end

end