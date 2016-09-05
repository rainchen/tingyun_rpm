
require File.expand_path(File.join(File.dirname(__FILE__),'..','..','test_helper'))

class RailsTest < Minitest::Test

  def test_install_browser_monitoring
    require 'ting_yun/middleware/browser_monitoring'
    middleware = stub('middleware config')
    config = stub('rails config', :middleware => middleware)
    middleware.expects(:use).with(TingYun::BrowserMonitoring)
    TingYun::Frameworks.framework.instance_eval { @browser_monitoring_installed = false }
    with_config(:'browser_monitoring.auto_instrument' => true) do
      TingYun::Frameworks.framework.install_browser_monitoring(config)
    end
  end
end
