# encoding: utf-8
module TingYun
  module Instrumentation
    module Rack
      module RackBuilder

        def run_with_tingyun(app, *args)
          unless TingYun::Agent.config[:disable_rack_middleware]
            proxy_app = ::TingYun::Rack::MiddlewareProxy.proxy(app, true)
            run_without_tingyun(proxy_app, *args)
          else
            run_without_tingyun(app, *args)
          end
        end

        def use_with_tingyun(middleware_class, *args, &blk)
          unless TingYun::Agent.config[:disable_rack_middleware]
            proxy_middleware_class = ::TingYun::Rack::MiddlewareProxy.proxy_middleware_class(middleware_class)
            use_without_tingyun(proxy_middleware_class, *args, &blk)
          else
            use_without_tingyun(middleware_class, *args, &blk)
          end
        end

        # defered detection to avoid something later required
        def to_app_with_tingyun_deferred_library_detection
          unless ::Rack::Builder._oa_deferred_detection_ran
            TingYun::Agent.logger.info "Doing deferred library-detection before Rack startup"
            LibraryDetection.detect!
            ::Rack::Builder._oa_deferred_detection_ran = true
          end

          result = to_app_without_tingyun
          _check_for_late_instrumentation(result)

          result
        end

        def _check_for_late_instrumentation(app)
          return if @checked_for_late_instrumentation
          @checked_for_late_instrumentation = true
          unless TingYun::Agent.config[:disable_rack_middleware]
            if ::TingYun::Rack::MiddlewareProxy.need_proxy?(app)
              :TingYun::Agent.logger.info("We weren't able to instrument all of your Rack middlewares.",
                                           "To correct this, ensure you 'require \"tingyun_rpm\"' before setting up your middleware stack.")
            end
          end
        end
      end
    end
  end
end