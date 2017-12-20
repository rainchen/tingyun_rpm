# encoding: utf-8
module TingYun
  module Http
    class AbstractRequest
      ERROR_MESSAGE = 'Subclasses of TingYun::Http::AbstractRequest must implement a '.freeze

      def []
        raise NotImplementedError, ERROR_MESSAGE + ':[] method'
      end

      def []=
        raise NotImplementedError, ERROR_MESSAGE + ':[]= method'
      end


    end
  end
end
