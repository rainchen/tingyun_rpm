# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'ting_yun/agent/instance_methods/start'
require 'ting_yun/agent/instance_methods/connect'
require 'ting_yun/agent/instance_methods/start_worker_thread'
require 'ting_yun/agent/instance_methods/container_data_manager'

module TingYun
  module Agent
    module InstanceMethods

      include Start
      include Connect
      include StartWorkerThread
      include ContainerDataManager


      def reset_to_default_configuration
        TingYun::Agent.config.remove_config_type(:manual)
        TingYun::Agent.config.remove_config_type(:server)
      end

      def stop_event_loop
        @event_loop.stop if @event_loop
      end


    end
  end
end