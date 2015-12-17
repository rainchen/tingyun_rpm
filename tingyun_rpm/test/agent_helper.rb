# encoding: utf-8
# This file is distributed under Ting Yun's license terms.with_array_logger
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

def with_config(config_hash, at_start=true)
  config = TingYun::Configuration::DottedHash.new(config_hash, true)
  TingYun::Agent.config.add_config_for_testing(config, at_start)
  begin
    yield
  ensure
    TingYun::Agent.config.remove_config(config)
  end
end

def with_environment(env)
  old_env = {}
  env.each do |key, val|
    old_env[key] = ENV[key]
    ENV[key]     = val.to_s
  end
  begin
    yield
  ensure
    old_env.each { |key, old_val| ENV[key] = old_val }
  end
end

# Need to guard against double-installing this patch because in 1.8.x the same
# file can be required multiple times under different non-canonicalized paths.
unless Time.respond_to?(:__original_now)
  Time.instance_eval do
    class << self
      attr_accessor :__frozen_now
      alias_method :__original_now, :now

      def now
        __frozen_now || __original_now
      end
    end
  end
end

def freeze_time(now=Time.now)
  Time.__frozen_now = now
end

def unfreeze_time
  Time.__frozen_now = nil
end

def advance_time(seconds)
  freeze_time(Time.now + seconds)
end
