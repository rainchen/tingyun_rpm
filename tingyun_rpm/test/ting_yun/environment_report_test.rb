# encoding: utf-8

require File.expand_path(File.join(File.dirname(__FILE__),'..','test_helper'))

require 'ting_yun/environment_report'



module TingYun
  class EnvironmentReportTest < Minitest::Test

    def setup
      @old_logic = ::TingYun::EnvironmentReport.registered_reporters.dup
      @report = ::TingYun::EnvironmentReport.new
    end

    def teardown
      ::TingYun::EnvironmentReport.registered_reporters = @old_logic
    end

    def test_converts_to_array
      ::TingYun::EnvironmentReport.report_on("something"){"awesome"}
      data = Array(::TingYun::EnvironmentReport.new)
      expected = ["something", "awesome"]
      assert data.include?(expected), "expected to find #{expected} in #{data.inspect}"
    end

    def test_register_a_value_to_report_on
      ::TingYun::EnvironmentReport.report_on("What time is it?") do
        "beer-o-clock"
      end
      assert_equal 'beer-o-clock', ::TingYun::EnvironmentReport.new["What time is it?"]
    end

    def test_report_on_handles_errors_gracefully
      ::TingYun::EnvironmentReport.report_on("What time is it?") do
        raise ArgumentError, "woah! something blew up"
      end
      assert_nil ::TingYun::EnvironmentReport.new["What time is it?"]
    end

    def test_it_does_not_set_keys_for_nil_values
      ::TingYun::EnvironmentReport.report_on("What time is it?") do
        nil
      end
      assert ! ::TingYun::EnvironmentReport.new.data.has_key?("What time is it?")
    end

    def test_can_set_an_environment_value_directly
      @report['My Value'] = 'so awesome!!'
      assert_equal 'so awesome!!', @report['My Value']
    end


    def test_gathers_ruby_version
      assert_equal RUBY_VERSION, @report['Ruby version']
    end

    def test_gathers_openssl_version
      refute_nil @report['OpenSSL version']
    end

    def test_gathers_system_info
      TingYun::Support::SystemInfo.stubs({
                                            :num_logical_processors => 8,
                                            :processor_arch         => 'x86_64',
                                            :os_version             => 'WiggleOS 1.1.1',
                                            :ruby_os_identifier     => 'wiggleos'
                                        })
      report = ::TingYun::EnvironmentReport.new
      assert_equal(8, report['Logical Processors'])
      assert_equal('x86_64', report['os_arch'])
      assert_equal('WiggleOS 1.1.1', report['os_version'])
      assert_equal('wiggleos', report['kernel'])
    end

    def test_has_logic_for_keys
      [
          'Gems',
          'Plugin List',
          'Ruby version',
          'Ruby description',
          'Ruby platform',
          'Ruby patchlevel',
          'JRuby version',
          'Java VM version',
          'Logical Processors',
          'Physical Cores',
          'Database adapter',
          'Framework',
          'Dispatcher',
          'Environment',
          'os_arch',
          'os_version',
          'kernel',
          'Rails Env',
          'Rails version',
          'Rails threadsafe',
          'OpenSSL version',
      ].each do |key|
        assert TingYun::EnvironmentReport.registered_reporters.has_key?(key), "Expected logic for #{key.inspect} in EnvironmentReport."
        end
      end
  end
end