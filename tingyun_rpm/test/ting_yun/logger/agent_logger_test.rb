require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/logger/agent_logger'
require 'ting_yun/logger/null_logger'

class ArrayLogDevice
  def initialize( array=[] )
    @array = array
  end
  attr_reader :array

  def write( message )
    @array << message
  end

  def close; end
end


class AgentLoggerTest < Minitest::Test

  LEVELS = [:fatal, :error, :warn, :info, :debug]

  def setup
  	::TingYun::Agent.config[:'nbs.agent_log_file_path'] = "log/"
    ::TingYun::Agent.config[:'nbs.agent_log_file_name'] = "test.log"
  end

  def teardown
    ::TingYun::Agent.config.clear
  end

  def test_create_log_from_config
  	@logger = TingYun::Logger::AgentLogger.new
  	wrapped_logger = @logger.instance_variable_get(:@log) 
  	logdev = wrapped_logger.instance_variable_get(:@logdev)
  	expected_logpath = File.expand_path(::TingYun::Agent.config[:'nbs.agent_log_file_path'] + ::TingYun::Agent.config[:'nbs.agent_log_file_name'])

  	assert_kind_of( Logger, wrapped_logger )
  	assert_kind_of( File, logdev.dev )
  	assert_equal( expected_logpath, logdev.filename )
  end

  def test_log_level
  	::TingYun::Agent.config[:'nbs.agent_log_level'] = 'unknown'

  	@logger = TingYun::Logger::AgentLogger.new
  	wrapped_logger = @logger.instance_variable_get(:@log) 

  	assert_equal(::Logger::INFO , wrapped_logger.level)

  	::TingYun::Agent.config[:'nbs.agent_log_level'] = 'debug'

  	@logger = TingYun::Logger::AgentLogger.new
  	wrapped_logger = @logger.instance_variable_get(:@log) 

  	assert_equal(::Logger::DEBUG , wrapped_logger.level)
  end

  def test_initalizes_from_override
    override_logger = Logger.new( '/dev/null' )
    logger = TingYun::Logger::AgentLogger.new("", override_logger)
    assert_equal override_logger, logger.instance_variable_get(:@log)
  end

  def test_forwards_calls_to_logger
  	::TingYun::Agent.config[:'nbs.agent_log_level'] = 'info'

  	logger = create_basic_logger

  	LEVELS.each do |level|
      logger.send(level, "Boo!")
    end

    assert_logged(/FATAL/,
                  /ERROR/,
                  /WARN/,
                  /INFO/) # No DEBUG
  end

  def test_forwards_calls_to_logger_with_multiple_arguments
  	logger = create_basic_logger

  	LEVELS.each do |level|
      logger.send(level, "What", "up?")
    end

    assert_logged(/FATAL/, /FATAL/,
                  /ERROR/, /ERROR/,
                  /WARN/,  /WARN/,
                  /INFO/,  /INFO/) # No DEBUG
  end

  def test_forwards_calls_to_logger_once
  	logger = create_basic_logger

  	LEVELS.each do |level|
      logger.send(:log_once, level, :special_key, "Special!")
    end

    assert_logged(/Special/)
  end

  def test_logs_to_stdout_if_fails_on_file
  	Logger::LogDevice.any_instance.stubs(:open).raises(Errno::EACCES)

  	logger = with_squelched_stdout do
      TingYun::Logger::AgentLogger.new
    end

  	wrapped_logger = logger.instance_variable_get(:@log)
    logdev = wrapped_logger.instance_variable_get(:@logdev)

    assert_equal $stdout, logdev.dev
  end

  def test_consider_any_other_logger_not_a_startup_logger
    logger = TingYun::Logger::AgentLogger.new
    refute logger.is_startup_logger?
  end

  def test_log_exception_logs_backtrace_at_same_level_as_message_by_default
    logger = create_basic_logger

    e = Exception.new("howdy")
    e.set_backtrace(["wiggle", "wobble", "topple"])

    logger.log_exception(:info, e)

    assert_logged(/INFO : Exception: howdy/i,
                  /INFO : Debugging backtrace:\n.*wiggle\s+wobble\s+topple/)
  end

  def test_log_exception_logs_backtrace_at_explicitly_specified_level
    logger = create_basic_logger

    e = Exception.new("howdy")
    e.set_backtrace(["wiggle", "wobble", "topple"])

    logger.log_exception(:warn, e, :info)

    assert_logged(/WARN : Exception: howdy/i,
                  /INFO : Debugging backtrace:\n.*wiggle\s+wobble\s+topple/)
  end

  def recursion_is_an_antipattern
    recursion_is_an_antipattern
  end

  def test_log_exception_gets_backtrace_for_system_stack_error
    # This facility compensates for poor SystemStackError traces on MRI.
    # JRuby and Rubinius raise errors with good backtraces, so skip this test.
    return if jruby? || rubinius?

    logger = create_basic_logger

    begin
      recursion_is_an_antipattern
    rescue SystemStackError => e
      logger.log_exception(:error, e)
    end

    assert_logged(/ERROR : /,
                  /ERROR : Debugging backtrace:\n.*#{__method__}/)
  end

 def test_should_cache_hostname
    Socket.expects(:gethostname).once.returns('cache-hostname')
    logger = create_basic_logger
    logger.warn("one")
    logger.warn("two")
    logger.warn("three")
    host_regex = /cache-hostname/
    assert_logged(host_regex, host_regex, host_regex)
  end

  def test_should_allow_blocks_that_return_a_single_string
    logger = create_basic_logger
    logger.warn { "Surely you jest!" }

    assert_logged(/WARN : Surely you jest!/)
  end

  def test_should_allow_blocks_that_return_an_array
    logger = create_basic_logger
    logger.warn do
      ["You must be joking!", "You can't be serious!"]
    end

    assert_logged(
      /WARN : You must be joking!/,
      /WARN : You can't be serious!/
    )
  end

  def test_can_overwrite_log_formatter
    log_message   = 'How are you?'
    log_formatter = Proc.new { |s, t, p, m| m.reverse }

    logger = create_basic_logger
    logger.log_formatter = log_formatter
    logger.warn log_message

    assert_logged log_message.reverse
  end

  def test_clear_already_logged
    logger = create_basic_logger
    logger.log_once(:warn, :positive, "thoughts")
    logger.log_once(:warn, :positive, "thoughts")

    assert_logged "thoughts"

    logger.clear_already_logged
    logger.log_once(:warn, :positive, "thoughts")

    assert_logged "thoughts", "thoughts"
  end

  

  #
  # Helpers
  #
  def create_basic_logger
  	@logdev = ArrayLogDevice.new
    override_logger = Logger.new(@logdev)
    TingYun::Logger::AgentLogger.new("", override_logger)
  end

  def logged_lines
  	@logdev.array
  end

  def assert_logged(*args)
  	assert_equal(args.length, logged_lines.length, "Unexpected log length #{logged_lines}")
  	logged_lines.each_with_index do |line, index|
      assert_match(args[index], line, "Missing match for #{args[index]}")
    end
  end

  def with_squelched_stdout
    orig = $stdout.dup
    $stdout.reopen( '/dev/null' )
    yield
  ensure
    $stdout.reopen( orig )
  end

end