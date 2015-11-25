# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'test_helper'))
require 'ting_yun/agent/instance_methods/start_worker_thread'
require 'ting_yun/agent'
require 'ting_yun/ting_yun_service'
require 'ting_yun/configuration/server_source'
require 'ting_yun/support/exception'


class TingYun::Agent::InstanceMethods::StartWorkerThreadTest < MiniTest::Test

  include TingYun::Agent::InstanceMethods::StartWorkerThread

  def test_start_worker_thread
    assert_kind_of ::Thread,start_worker_thread
  end

  def test_deferred_work!
    self.expects(:connect).returns(true)
    self.expects(:connected?).returns(false)
    assert deferred_work!({}),"should be true"
  end

  def test_deferred_work_connects
    self.expects(:connect).with('connection_options')
    self.stubs(:connected?).returns(true)
    self.expects(:create_and_run_event_loop)
    deferred_work!('connection_options')
  end

  def test_deferred_work_connect_failed
    self.expects(:connect).with('connection_options')
    self.stubs(:connected?).returns(false)
    deferred_work!('connection_options')
  end

end