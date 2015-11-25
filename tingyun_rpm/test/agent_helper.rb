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