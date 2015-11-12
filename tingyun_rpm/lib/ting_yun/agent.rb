# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'forwardable'

module TingYun
	module Agent
 		extend self
    	extend Forwardable

    	require 'ting_yun/logger/agent_logger'


    	@agent = nil
    	@logger = nil

    	def agent
    		return @agent if @agent
     		TingYun::Agent.logger.warn("Agent unavailable as it hasn't been started.")
      		TingYun::Agent.logger.warn(caller.join("\n"))
    		nil
    	end

    	def logger
    		@logger || StartupLogger.instance
    	end

    	def logger=(log)
      		@logger = log
    	end

    	
	end
end