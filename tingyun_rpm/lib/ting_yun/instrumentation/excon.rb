TingYun::Support::LibraryDetection.defer do
  named :excon

  EXCON_MIN_VERSION = Gem::Version.new("0.10.1")
  EXCON_MIDDLEWARE_MIN_VERSION = Gem::Version.new("0.19.0")

  depends_on do
    defined?(::Excon) && defined?(::Excon::VERSION)
  end

  executes do
    excon_version = Gem::Version.new(::Excon::VERSION)
    if excon_version >= EXCON_MIN_VERSION
      install_excon_instrumentation(excon_version)
    else
      ::TingYun::Agent.logger.warn("Excon instrumentation requires at least version #{EXCON_MIN_VERSION}")
    end
  end

  def install_excon_instrumentation(excon_version)
    require 'ting_yun/agent/cross_app/cross_app_tracing'
    require 'ting_yun/http/excon_wrappers'

    if excon_version >= EXCON_MIDDLEWARE_MIN_VERSION
      install_middleware_excon_instrumentation
    else
      install_legacy_excon_instrumentation
    end
  end

  def install_middleware_excon_instrumentation
    ::TingYun::Agent.logger.info 'Installing middleware-based Excon instrumentation'
    require 'new_NewRelicrelic/agent/instrumentation/excon/middleware'
    defaults = Excon.defaults

    if defaults[:middlewares]
      defaults[:middlewares] << ::Excon::Middleware::NewRelicCrossAppTracing
    else
      ::TingYun::Agent.logger.warn("Did not find :middlewares key in Excon.defaults, skipping Excon instrumentation")
    end
  end

  def install_legacy_excon_instrumentation
    ::TingYun::Agent.logger.info 'Installing legacy Excon instrumentation'
    require 'new_relic/agent/instrumentation/excon/connection'
    ::Excon::Connection.install_newrelic_instrumentation
  end


end