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



end