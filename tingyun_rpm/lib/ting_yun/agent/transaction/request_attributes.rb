# encoding: utf-8

require 'ting_yun/support/http_clients/uri_util'

module TingYun
  module Agent
    class Transaction
      class RequestAttributes

        attr_reader :request_path, :referer, :accept, :content_length, :host,
                    :port, :user_agent, :request_method

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
        end


        private

        # Make a safe attempt to get the referer from a request object, generally successful when
        # it's a Rack request.

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

        def assign_agent_attributes(txn)

          if request_path
            txn.add_agent_attribute :'request.headers.request_path', request_path
          end

          if referer
            txn.add_agent_attribute :'request.headers.referer', referer
          end

          if accept
            txn.add_agent_attribute :'request.headers.accept', accept
          end

          if content_length
            txn.add_agent_attribute :'request.headers.contentLength', content_length
          end

          if host
            txn.add_agent_attribute :'request.headers.host', host
          end

          if port
            txn.add_agent_attribute :'request.headers.port', port
          end

          if user_agent
            txn.add_agent_attribute :'request.headers.userAgent', user_agent
          end

          if request_method
            txn.add_agent_attribute :'request.headers.method', request_method
          end
        end

      end
    end
  end
end
