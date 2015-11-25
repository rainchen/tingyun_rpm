# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent/threading/agent_thread'
require 'ting_yun/agent/event/event_loop'

module TingYun
  module Agent
    module InstanceMethods
      module StartWorkerThread
        def start_worker_thread(connection_options={})
          TingYun::Agent.logger.debug "Creating Ruby Agent worker thread."
          @worker_thread = TingYun::Agent::Threading::AgentThread.create('Worker Loop') do
            deferred_work!(connection_options)
          end
        end

        # This is the method that is run in a new thread in order to
        # background the harvesting and sending of data during the
        # normal operation of the agent.
        #
        # Takes connection options that determine how we should
        # connect to the server, and loops endlessly - typically we
        # never return from this method unless we're shutting down
        # the agent
        def deferred_work!(connection_options)
          connect(connection_options)
          if connected?
            create_and_run_event_loop
          else
            TingYun::Agent.logger.debug "No connection.  Worker thread ending."
          end
        end

        def create_and_run_event_loop
          @event_loop = EventLoop.new
        end
      end
    end
  end
end