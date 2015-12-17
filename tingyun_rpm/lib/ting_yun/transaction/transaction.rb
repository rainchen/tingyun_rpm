# encoding: utf-8
require 'ting_yun/support/http_clients/uri_util'

module TingYun
  module Agent

    # This class represents a single transaction (usually mapping to one
    # web request or background job invocation) instrumented by the Ruby agent.
    class Transaction

      # A Time instance for the start time, never nil
      attr_accessor :start_time

      def initialize(category, options)
        @frame_stack = []
        @has_children = false
        @category = category
        @start_time = Time.now
        @apdex_start = options[:apdex_start_time] || @start_time
        @filtered_params = options[:filtered_params] || {}


        if request = options[:request]
          @request_path = path_from_request(request)
          @referer = referer_from_request(request)
        end
      end

      # Make a safe attempt to get the referer from a request object, generally successful when
      # it's a Rack request.
      def referer_from_request(req)
        if req && req.respond_to?(:referer) && req.referer
          HTTPClients::URIUtil.strip_query_string(req.referer.to_s)
        end
      end

      # In practice we expect req to be a Rack::Request or ActionController::AbstractRequest
      # (for older Rails versions).  But anything that responds to path can be passed to
      # perform_action_with_tingyun_trace.
      #
      # We don't expect the path to include a query string, however older test helpers for
      # rails construct the PATH_INFO enviroment variable improperly and we're generally
      # being defensive.
      def path_from_request(req)
        path = req.path
        path = HTTPClients::URIUtil.strip_query_string(path)
        path.empty? ? "/" : path
      end





      module ClassMethods

        def start(state, category, options={})
          category ||= :controller

          if txn = state.current_transaction
            txn.create_nested_frame(state, category, options)
          else
            txn = start_new_transaction(state, category, options)
          end
        end

        def start_new_transaction(state, category, options)
          txn = Transaction.new(category,options)
          state.reset(txn)
          txn
        end

        def stop(state, end_time=Time.now)
          txn = state.current_transaction

          unless txn
            TingYun::Agent.logger.error('Failed during Transaction.stop because there is no current transaction')
            return
          end
        end
      end
      extend ClassMethods


      module InstanceMethods
        def create_nested_frame(state, category, options)
          @has_children = true
          if options[:filtered_params] && !options[:filtered_params].empty?
            @filtered_params = options[:filtered_params]
            merge_request_parameters(options[:filtered_params])
          end


        end

        def merge_request_parameters(params)
        end
      end
      include InstanceMethods







    end
  end
end
