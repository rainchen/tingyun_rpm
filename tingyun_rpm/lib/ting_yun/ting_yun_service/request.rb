# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
module TingYun
  class TingYunService
    module Request

      #Posts to the specified server, only try to request twice if there any exception in the first time
      def send_request(opts)
        request = Net::HTTP::Post.new(opts[:uri], 'CONTENT-ENCODING' => opts[:encoding], 'HOST' => opts[:collector].name)
        request['user-agent'] = user_agent
        request.content_type = "application/octet-stream"
        request.body = opts[:data]

        attempts = 0
        max_attempts = 2

        begin
          attempts += 1
          conn = http_connection
          TingYun::Agent.logger.debug "Sending request to #{opts[:collector]}#{opts[:uri]}"
          TingYun::Support::TimerLib.timeout(@request_timeout) do
            response = conn.request(request)
          end
        rescue *CONNECTION_ERRORS => e
          close_shared_connection
          if attempts < max_attempts
            TingYun::Agent.logger.debug("Retrying request to #{opts[:collector]}#{opts[:uri]} after #{e}")
            retry
          else
            raise TingYun::Support::Exception::ServerConnectionException, "Recoverable error talking to #{@collector} after #{attempts} attempts: #{e}"
          end
        end

        TingYun::Agent.logger.debug "Received response, status: #{response.code}, encoding: '#{response['content-encoding']}'"


        case response
          when Net::HTTPSuccess
            true # do nothing
          when Net::HTTPUnauthorized
            raise LicenseException, 'Invalid license key, please visit support.newrelic.com'
          when Net::HTTPServiceUnavailable
            raise ServerConnectionException, "Service unavailable (#{response.code}): #{response.message}"
          when Net::HTTPGatewayTimeOut
            raise ServerConnectionException, "Gateway timeout (#{response.code}): #{response.message}"
          when Net::HTTPRequestEntityTooLarge
            raise UnrecoverableServerException, '413 Request Entity Too Large'
          when Net::HTTPUnsupportedMediaType
            raise UnrecoverableServerException, '415 Unsupported Media Type'
          else
            raise ServerConnectionException, "Unexpected response from server (#{response.code}): #{response.message}"
        end
        response
      end



      def compress_request_if_needed(data)
        encoding = 'identity'
        if data.size > 64*1024
          data = TingYun::Support::Serialize::Encoders::Compressed.encode(data)
          encoding = 'deflate'
        end
        check_post_size(data)
        [data, encoding]
      end

      def check_post_size(post)
        return if post.size < TingYun::Agent.config[:post_size_limit]
        TingYun::Agent.logger.debug "Tried to send too much data: #{post.size} bytes"
        raise TingYun::Support::Exception::UnrecoverableServerException.new('413 Request Entity Too Large')
      end

      def user_agent
        ruby_description = ''
        # note the trailing space!
        ruby_description << "(ruby #{::RUBY_VERSION} #{::RUBY_PLATFORM}) " if defined?(::RUBY_VERSION) && defined?(::RUBY_PLATFORM)
        zlib_version = ''
        zlib_version << "zlib/#{Zlib.zlib_version}" if defined?(::Zlib) && Zlib.respond_to?(:zlib_version)
        "NBS Newlens Agent/#{TingYun::VERSION::STRING} #{ruby_description}#{zlib_version}"
      end
    end
  end
end