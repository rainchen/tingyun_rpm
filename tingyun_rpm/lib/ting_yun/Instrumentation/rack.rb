# encoding: utf-8
require 'ting_yun/instrumentation/rack/rack_builder'

TingYun::Support::LibraryDetection.defer do
  named :rack

  depends_on do
    defined?(::Rack) && defined?(::Rack::Builder)
  end

  executes do
    TingYun::Agent.logger.info 'Installing deferred Rack instrumentation'

    class ::Rack::Builder
      class << self
        attr_accessor :_oa_deferred_detection_ran
      end

      self._oa_deferred_detection_ran = false

      include ::TingYun::Instrumentation::Rack::RackBuilder

      alias_method :to_app_without_tingyun, :to_app
      alias_method :to_app, :to_app_with_tingyun_deferred_library_detection

      unless TingYun::Agent.config[:disable_rack_middleware]
        TingYun::Agent.logger.info 'Installing Rack::Builder middleware instrumentation'
      end

      alias_method :run_without_tingyun, :run
      alias_method :run, :run_with_tingyun

      alias_method :use_without_tingyun, :use
      alias_method :use, :use_with_tingyun


    end
  end
end

