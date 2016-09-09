# encoding: utf-8
require 'ting_yun/middleware/agent_middleware'


module TingYun
  class BrowserMonitoring < AgentMiddleware

    def traced_call(env)
      result = @app.call(env)   # [status, headers, response]

      js_to_inject = TingYun::Agent.browser_timing_header
    end
  end
end
