# encoding: utf-8

require 'ting_yun/support/http_clients/uri_util'

module TingYun
  module Agent
    class Transaction
      class RequestAttributes

        attr_reader :request_path, :referer, :accept, :content_length, :host,
                    :port, :user_agent, :request_method, :query_string

        HTTP_ACCEPT_HEADER_KEY = "HTTP_ACCEPT".freeze

        def initialize request
          @request_path = path_from_request request
          @referer = referer_from_request request
          @accept = attribute_from_env request, HTTP_ACCEPT_HEADER_KEY
          @content_length = content_length_from_request request
          @host = attribute_from_request request, :host
          @port = port_from_request request
          @user_agent = attribute_from_request request, :user_agent
          @request_method = attribute_from_request request, :request_method
          @query_string = attribute_from_request request, :query_string
        end

        def assign_agent_attributes(txn)

          if request_path
            txn.add_agent_attribute :request_path, request_path
          end

          if referer
            txn.add_agent_attribute :referer, referer
          end

          if accept
            txn.add_agent_attribute :accept, accept
          end

          if content_length
            txn.add_agent_attribute :contentLength, content_length
          end

          if host
            txn.add_agent_attribute :host, host
          end

          if port
            txn.add_agent_attribute :port, port
          end

          if user_agent
            txn.add_agent_attribute :userAgent, user_agent
          end

          if request_method
            txn.add_agent_attribute :method, request_method
          end

          if query_string
            txn.add_agent_attribute :request_params, request_params
          end
        end


        private

        # Make a safe attempt to get the referer from a request object, generally successful when
        # it's a Rack request.

        def request_params
          hash = {}
          return hash if @query_string.empty?
          query_string.split("&").each do |param|
            _k,_v = param.strip.split("=")
            hash[_k] = _v unless _v.nil?
          end

          return hash
        end

        def referer_from_request request
          if referer = attribute_from_request(request, :referer)
            TingYun::Agent::HTTPClients::URIUtil.strip_query_string referer.to_s
          end
        end



        ROOT_PATH = "/".freeze

        def path_from_request request
          path = attribute_from_request(request, :path) || ''
          path = TingYun::Agent::HTTPClients::URIUtil.strip_query_string(path)
          path.empty? ? ROOT_PATH : path
        end

        def content_length_from_request request
          if content_length = attribute_from_request(request, :content_length)
            content_length.to_i
          end
        end

        def port_from_request request
          if port = attribute_from_request(request, :port)
            port.to_i
          end
        end

        def attribute_from_request request, attribute_method
          if request.respond_to? attribute_method
            request.send(attribute_method)
          end
        end

        def attribute_from_env request, key
          if env = attribute_from_request(request, :env)
            env[key]
          end
        end

      end
    end
  end
end
