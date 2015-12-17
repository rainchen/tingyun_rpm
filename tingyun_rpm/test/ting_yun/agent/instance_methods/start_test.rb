# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper'))
require 'ting_yun/agent/instance_methods/start'
require 'ting_yun/agent'
require 'ting_yun/ting_yun_service'
require 'ting_yun/configuration/server_source'
require 'ting_yun/support/exception'


class TingYun::Agent::InstanceMethods::StartTest < MiniTest::Test

  include TingYun::Agent::InstanceMethods::Start

  def setup
    @started = true
  end

  def test_already_started_negative
    self.expects(:started?).returns(false)
    assert !already_started?
  end


  def test_disabled_positive
    with_config(:'nbs.agent_enabled' => false) do
      assert disabled?
    end
  end

  def test_disabled_negative
    with_config(:'nbs.agent_enabled' => true) do
      assert !disabled?
    end
  end

  def test_already_started?
    assert already_started?,"should return true"
    @started = false
    assert_nil already_started?
  end

  def test_agent_should_start?
    TingYun::Agent.config.add_config_for_testing(:'nbs.agent_enabled' => true )
    refute agent_should_start?,"should be false"
    TingYun::Agent.config.reset_to_defaults
    @started = false
    assert agent_should_start?,"should be false"
  end

  def test_monitoring_positive
    with_config(:monitor_mode => true) do
      assert monitoring?
    end
  end

  def test_monitoring_negative
    with_config(:monitor_mode => false) do
      assert !monitoring?
    end
  end

  def test_has_license_key_positive
    with_config(:license_key => 'a' * 40) do
      assert has_license_key?
    end
  end

  def test_has_license_key_negative
    with_config(:license_key => false) do
      assert !has_license_key?
    end
  end

  def test_has_correct_license_key_positive
    self.expects(:has_license_key?).returns(true)
    self.expects(:correct_license_length).returns(true)
    assert has_correct_license_key?
  end

  def test_has_correct_license_key_negative
    self.expects(:has_license_key?).returns(false)
    assert !has_correct_license_key?
  end

  def test_correct_license_length_positive
    with_config(:license_key => 'a' * 40) do
      assert correct_license_length
    end
  end

  def test_correct_license_length_negative
    with_config(:license_key => 'a' * 30) do
      assert !correct_license_length
    end
  end


  def test_using_forking_dispatcher_positive
    with_config(:dispatcher => :passenger) do
      assert is_using_forking_dispatcher?
    end
  end

  def test_using_forking_dispatcher_negative
    with_config(:dispatcher => :frobnitz) do
      assert !is_using_forking_dispatcher?
    end
  end

end