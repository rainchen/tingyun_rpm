# encoding: utf-8
require 'ting_yun/instrumentation/middleware_proxy'

module TingYun
  class AgentMiddleware

    include TingYun::Instrumentation::MiddlewareTracing

    def initialize(app)
      @app = app
      @category = :middleware
    end


  end
end
