# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.

require File.expand_path(File.join(File.dirname(__FILE__),'..','..','..','test_helper'))
require 'ting_yun/agent/threading/agent_thread'
require 'ting_yun/agent'

module TingYun::Agent::Threading
  class AgentThreadTest < Minitest::Test

    def test_sets_label
      t = AgentThread.create("labelled") {}
      assert_equal "labelled", t[:TingYun_label]
      t.join
    end

    def test_runs_block
      called = false

      t = AgentThread.create("labelled") { called = true }
      t.join

      assert called
    end

    def test_standard_error_is_caught
      expects_logging(:error, includes("exited"), any_parameters)

      t = AgentThread.create("fail") { raise "O_o" }
      t.join

      assert_thread_completed(t)
    end

    def test_exception_is_reraised
      expects_logging(:error, includes("exited"), any_parameters)

      assert_raises(Exception) do
        begin
          t = AgentThread.create("fail") { raise Exception.new }
          t.join
        ensure
          assert_thread_died_from_exception(t)
        end
      end
    end


    def assert_thread_completed(t)
      assert_equal false, t.status
    end

    def assert_thread_died_from_exception(t)
      assert_equal nil, t.status
    end

  end
end
