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

