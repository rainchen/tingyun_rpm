# encoding: utf-8
# This file is distributed under Ting Yun's license terms.
require 'net/https'
require 'net/http'
require 'ting_yun/ting_yun_service/ssl'
require 'ting_yun/ting_yun_service/request'
require 'ting_yun/ting_yun_service/connection'

module TingYun
  module TingYunService
    module Http

      include Ssl
      include Request
      include Connection

      def remote_method_uri(method)
        params = {'licenseKey'=> @license_key,'appSessionKey' => @app_session_key,'version' => @data_version}
        uri = '#{method}'
        uri << '?' + params.map do |k,v|
          next unless v
          "#{k}=#{v}"
        end.compact.join('&')
        uri
      end
    end
  end
end