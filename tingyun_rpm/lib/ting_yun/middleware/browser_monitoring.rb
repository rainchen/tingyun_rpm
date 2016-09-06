# encoding: utf-8
require 'ting_yun/middleware/agent_middleware'


module TingYun
  class BrowserMonitoring < AgentMiddleware

    def traced_call(env)
      result = @app.call(env)   # [status, headers, response]
    end
  end
end
