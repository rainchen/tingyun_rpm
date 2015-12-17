require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))
require 'ting_yun/logger/memory_logger'

class MemoryLoggerTest < Minitest::Test
  LEVELS = [:fatal, :error, :warn, :info, :debug]

  def setup
  	@logger = ::TingYun::Logger::MemoryLogger.new
  end

  def test_proxies_messages_to_real_logger_on_dump
  	LEVELS.each do |level|
  		@logger.send(level,"message at #{level}")
  	end

	real_logger = mock
  	real_logger.expects(:fatal).with("message at fatal")
    real_logger.expects(:error).with("message at error")
    real_logger.expects(:warn).with("message at warn")
    real_logger.expects(:info).with("message at info")
    real_logger.expects(:debug).with("message at debug")

    @logger.dump(real_logger)
  end

  def test_proxies_multiple_messages_with_a_single_call
    @logger.info('a', 'b', 'c')

    real_logger = mock
    real_logger.expects(:info).with('a', 'b', 'c')

    @logger.dump(real_logger)
  end

  def test_proxies_message_blocks
    called = false
    @logger.info('a') do  
   	  called = true
   	end

    real_logger = mock
    real_logger.expects(:info).yields

    @logger.dump(real_logger)
    assert called
  end

  def test_proxies_through_calls_to_log_exception
    e = Exception.new
    @logger.log_exception(:fatal, e, :error)

    real_logger = stub
    real_logger.expects(:log_exception).with(:fatal, e, :error)

    @logger.dump(real_logger)
  end

  def test_log_once
    @logger.log_once(:debug, :once, "Once")
    @logger.log_once(:debug, :once, "Twice?")

    real_logger = stub
    real_logger.expects(:debug).once

    @logger.dump(real_logger)
  end

end
