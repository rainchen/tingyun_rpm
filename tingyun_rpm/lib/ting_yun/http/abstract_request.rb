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

      def from
        raise NotImplementedError, ERROR_MESSAGE + ':from method'
      end


    end
  end
end
