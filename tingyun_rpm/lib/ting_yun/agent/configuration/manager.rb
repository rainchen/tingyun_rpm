# encoding: utf-8
# This file is distributed under Ting Yun's license terms.

require 'ting_yun/agent/configuration/default_source'

module TingYun
	module Agent
		module Configuration
			module Manger
				def initialize
					reset_to_defaults
				end

				def [](key)
					@cache(key)
				end

				def has_key?(key)
				    @cache.has_key?[key]
				end

				def keys
					@cache.keys
				end


				def reset_to_defaults
					@default_source = DefaultSource.new

					reset_cache
				end

				def reset_cache
					@cache = Hash.new {|hash,key| hash[key] = self.fetch(key) }
				end

				def fetch(key)
					config_stack.each do |config|
						next unless config
						accessor = key.to_sym

						if config.has_key?(accessor)
							evaluated = evaluate_procs(config[accessor]) #if it's proc

							begin

							rescue
								next
							end

						end
					end
					nil
				end

				def evaluate_procs(value)
					if value.respond_to?(:call)
						instance_eval(&value)
					else
						value
					end
				end


				private

				def config_stack
					stack = [@default_source]

					stack.compact!
				end
			end
		end
	end
end