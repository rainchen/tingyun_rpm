# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'thread'
require 'logger'
require 'ting_yun/logger/log_once'
require 'ting_yun/logger/memory_logger'
require 'ting_yun/support/hostname'
require 'ting_yun/logger/null_logger'


module TingYun
  module Logger
    class AgentLogger
      include LogOnce

      def initialize(root = "", override_logger=nil)
        @already_logged_lock = Mutex.new
        clear_already_logged
        create_log(root, override_logger)
        set_log_level!
        set_log_format!

        gather_startup_logs
      end

      def fatal(*msgs, &blk)
        format_and_send(:fatal, msgs, &blk)
      end

      def error(*msgs, &blk)
        format_and_send(:error, msgs, &blk)
      end

      def warn(*msgs, &blk)
        format_and_send(:warn, msgs, &blk)
      end

      def info(*msgs, &blk)
        format_and_send(:info, msgs, &blk)
      end

      def debug(*msgs, &blk)
        format_and_send(:debug, msgs, &blk)
      end

      def is_startup_logger?
        @log.is_a?(NullLogger)
      end

      # Use this when you want to log an exception with explicit control over
      # the log level that the backtrace is logged at. If you just want the
      # default behavior of backtraces logged at debug, use one of the methods
      # above and pass an Exception as one of the args.
      def log_exception(level, e, backtrace_level=level)
        @log.send(level, "%p: %s" % [e.class, e.message])
        @log.send(backtrace_level) do
          backtrace = backtrace_from_exception(e)
          if backtrace
            "Debugging backtrace:\n" + backtrace.join("\n  ")
          else
            "No backtrace available."
          end
        end
      end

      def log_formatter=(formatter)
        @log.formatter = formatter
      end

      private

      def backtrace_from_exception(e)
        # We've seen that often the backtrace on a SystemStackError is bunk
        # so massage the caller instead at a known depth.
        #
        # Tests keep us honest about minmum method depth our log calls add.
        return caller.drop(5) if e.is_a?(SystemStackError)

        e.backtrace
      end

      # Allows for passing exception.rb in explicitly, which format with backtrace
      def format_and_send(level, *msgs, &block)
        check_log_file
        if block
          if @log.send("#{level}?")
            msgs = Array(block.call)
          else
            msgs = []
          end
        end

        msgs.flatten.each do |item|
          case item
            when Exception then
              log_exception(level, item, :debug)
            else
              @log.send(level, item)
          end
        end
        nil
      end

      def check_log_file
        unless File.exist? @file_path
          begin
            @log = ::Logger.new(@file_path)
            set_log_format!
          rescue => e
            @log = ::Logger.new(STDOUT)
            warn("check_log_file:  Failed creating logger for file #{@file_path}, using standard out for logging.", e)
          end
        end
      end

      def create_log(root, override_logger)
        if !override_logger.nil?
          @log = override_logger
        elsif ::TingYun::Agent.config[:'nbs.agent_enabled'] == false
          create_null_logger
        else
          if wants_stdout?
            @log = ::Logger.new(STDOUT)
          else
            create_log_to_file(root)
          end
        end
      end

      def create_log_to_file(root)
        path = find_or_create_file_path(::TingYun::Agent.config[:agent_log_file_path], root)
        if path.nil?
          @log = ::Logger.new(STDOUT)
          warn("Error creating log directory #{::TingYun::Agent.config[:agent_log_file_path]}, using standard out for logging.")
        else
          @file_path = "#{path}/#{::TingYun::Agent.config[:agent_log_file_name]}"
          begin
            @log = ::Logger.new(@file_path)
          rescue => e
            @log = ::Logger.new(STDOUT)
            warn("Failed creating logger for file #{@file_path}, using standard out for logging.", e)
          end
        end
      end

      def create_null_logger
        @log = ::TingYun::Logger::NullLogger.new
      end

      def wants_stdout?
        ::TingYun::Agent.config[:agent_log_file_name].upcase == "STDOUT"
      end

      def find_or_create_file_path(path_setting, root)
        for abs_path in [File.expand_path(path_setting),
                         File.expand_path(File.join(root, path_setting))] do
          if File.directory?(abs_path) || (Dir.mkdir(abs_path) rescue nil)
            return abs_path[%r{^(.*?)/?$}]
          end
        end
        nil
      end

      def set_log_level!
        @log.level = AgentLogger.log_level_for(::TingYun::Agent.config[:agent_log_level])
      end

      LOG_LEVELS = {
          "debug" => ::Logger::DEBUG,
          "info" => ::Logger::INFO,
          "warn" => ::Logger::WARN,
          "error" => ::Logger::ERROR,
          "fatal" => ::Logger::FATAL,
      }

      def self.log_level_for(level)
        LOG_LEVELS.fetch(level.to_s.downcase, ::Logger::INFO)
      end

      def set_log_format!
        @hostname = TingYun::Support::Hostname.get
        @prefix = wants_stdout? ? '** [TingYun]' : ''
        @log.formatter = Proc.new do |severity, timestamp, progname, msg|
          "#{@prefix}[#{timestamp.strftime("%m/%d/%y %H:%M:%S %z")} #{@hostname} (#{$$})] #{severity} : #{msg}\n"
        end
      end

      #send the statup log info from memory to the agent log
      def gather_startup_logs
        StartupLogger.instance.dump(self)
      end

    end
  end
end
