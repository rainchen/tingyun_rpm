# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


require 'forwardable'

module TingYun
  module Agent
    module Configuration

      # Helper since default Procs are evaluated in the context of this module
      def self.value_of(key)
        # Proc.new do
        #   NewRelic::Agent.config[key]
        # end
      end

      class Boolean; end

      class DefaultSource
        attr_reader :defaults

        extend Forwardable
        def_delegators :@defaults, :has_key?, :each, :merge, :delete, :keys, :[], :to_hash

        def initialize
          @defaults = default_values
        end
        def default_values
          result = {}
          ::TingYun::Agent::Configuration::DEFAULTS.each do |key, value|
            result[key] = value[:default]
          end
          result
        end
        def self.auto_app_naming
          Proc.new{ true}
        end
        def self.audit_log_path
           Proc.new {
            # File.join(NewRelic::Agent.config[:log_file_path], 'newrelic_audit.log')
          }
        end
        def self.agent_enabled
          # Proc.new {
          #   TingYun::Agent.config[:enabled] &&
          #   (TingYun::Agent.config[:developer_mode] || TingYun::Agent.config[:monitor_mode]) &&
          #   TingYun::Agent::Autostart.agent_should_start?
          # }
          Proc.new { true}
        end
        def self.audit_log_path
          Proc.new {
            File.join(NewRelic::Agent.config[:log_file_path], 'newrelic_audit.log')
          }
        end
        def self.app_name
          Proc.new { NewRelic::Control.instance.env }
        end
        def self.port
          Proc.new { NewRelic::Agent.config[:ssl] ? 443 : 80 }
        end
        def self.action_tracer_action_threshold
          Proc.new { NewRelic::Agent.config[:apdex_f] * 4 }
        end
      end
      AUTOSTART_BLACKLISTED_RAKE_TASKS = [
        'about',
        'assets:clean',
        'assets:clobber',
        'assets:environment',
        'assets:precompile',
        'assets:precompile:all',
        'db:create',
        'db:drop',
        'db:fixtures:load',
        'db:migrate',
        'db:migrate:status',
        'db:rollback',
        'db:schema:cache:clear',
        'db:schema:cache:dump',
        'db:schema:dump',
        'db:schema:load',
        'db:seed',
        'db:setup',
        'db:structure:dump',
        'db:version',
        'doc:app',
        'log:clear',
        'middleware',
        'notes',
        'notes:custom',
        'rails:template',
        'rails:update',
        'routes',
        'secret',
        'spec',
        'spec:features',
        'spec:requests',
        'spec:controllers',
        'spec:helpers',
        'spec:models',
        'spec:views',
        'spec:routing',
        'spec:rcov',
        'stats',
        'test',
        'test:all',
        'test:all:db',
        'test:recent',
        'test:single',
        'test:uncommitted',
        'time:zones:all',
        'tmp:clear',
        'tmp:create'
      ].join(',').freeze

      DEFAULTS = {
        :"nbs.license_key" => {
          :default => '',
          :public => true,
          :type => String,
          :allowed_from_server => false,
          :description => 'Your Ting Yun <a href="">license key</a>.'
        },
        :'nbs.agent_enabled' => {
          :default => DefaultSource.agent_enabled,
          :public => true,
          :type => Boolean,
          :allowed_from_server => false,
          :description => 'Enable or disable the agent.'
        },
        :"nbs.app_name" => {
          :default => DefaultSource.app_name,
          :public => true,
          :type => String,
          :allowed_from_server => false,
          :description => 'Semicolon-delimited list of Naming your application.'
        },
        :"nbs.auto_app_naming" => {
          :default => DefaultSource.auto_app_naming,
          :public => true,
          :type => Boolean,
          :allowed_from_server => false,
          :description => 'Enable or disable to identify the application name'
        },
        :"nbs.agent_log_file_name" => {
          :default => DefaultSource.audit_log_path,
          :public => true,
          :type => String,
          :allowed_from_server => false,
          :description => 'Specifies a path to the audit log file (including the filename).'
        },
        :"nbs.audit_mode" => {
          :default => false,
          :public => true,
          :type => Boolean,
          :allowed_from_server => false,
          :description => 'Enable or disable to log the transmission-date for developer'
        },
        :"nbs.agent_log_level" => {
          :default => 'info',
          :public => true,
          :type => String,
          :allowed_from_server => false,
          :description => 'Log level for agent logging: critical, error, warning, info, verbose or debug.'
        },
        :"nbs.proxy_host" => {
          :default => nil,
          :allow_nil => true,
          :public => true,
          :type => String,
          :allowed_from_server => false,
          :description => 'Defines a host for communicating with Ting Yun via a proxy server.'
        },
        :"nbs.proxy_port" => {
          :default => 8080,
          :allow_nil => true,
          :public => true,
          :type => Fixnum,
          :allowed_from_server => false,
          :description => 'Defines a port for communicating with Ting Yun via a proxy server.'
        },
         :"nbs.proxy_user" => {
          :default => nil,
          :allow_nil => true,
          :public => true,
          :type => String,
          :allowed_from_server => false,
          :exclude_from_reported_settings => true,
          :description => 'Defines a user for communicating with Ting Yun via a proxy server.'
        },
        :"nbs.proxy_password" => {
          :default => nil,
          :allow_nil => true,
          :public => true,
          :type => String,
          :allowed_from_server => false,
          :exclude_from_reported_settings => true,
          :description => 'Defines a password for communicating with Ting Yun via a proxy server.'
        },
        :"nbs.host" => {
          :default => '',
          :public => false,
          :type => String,
          :allowed_from_server => false,
          :description => "URI for the Ting Yun data collection service."
        },
        :"nbs.port" => {
          :default => DefaultSource.port,
          :public => false,
          :type => Fixnum,
          :allowed_from_server => false,
          :description => 'Port for the Ting Yun data collection service.'
        },
        :"nbs.ssl" => {
          :default => true,
          :allow_nil => true,
          :public => true,
          :type => Boolean,
          :allowed_from_server => false,
          :description => 'Enable or disable SSL for transmissions to the Ting Yun'
        },
        :'nbs.action_tracer.log_sql' => {
          :default => false,
          :public => true,
          :type => Boolean,
          :allowed_from_server => false,
          :description => 'Enable or disable(write into log file) collection of SQL queries.'
        },
        :"nbs.daemon_debug" => {
          :default => false,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable(result-json contains key-id) debug mode'
        },
        :"nbs.urls_captured" => {
          :default => '',
          :public => true,
          :type => String,
          :allowed_from_server => true,
          :description => 'Enable or disable Specifies url'
        },
        :"nbs.auto_action_naming" => {
          :default => true,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable to use default name '
        },
       :"nbs.capture_params" => {
          :default => false,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable the capture of HTTP request parameters to be attached to transaction traces and traced errors.'
        },
        :"nbs.ignored_params" => {
          :default => '',
          :public => true,
          :type => String,
          :allowed_from_server => true,
          :description => 'Enable or disable Specifies HTTP request parameters '
        },
        :"nbs.error_collector.enabled" => {
          :default => true,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable recording of traced errors and error count metrics.'
        },
        :"nbs.error_collector.ignored_status_codes" => {
          :default => '',
          :public => true,
          :type => String,
          :allowed_from_server => true,
          :description => 'Enable or disable Specifies HTTP response code '
        },
        :"nbs.web_action_uri_params_captured" => {
          :default => '',
          :public => true,
          :type => String,
          :allowed_from_server => true,
          :description => 'Enable or disable Specifies WebAction request parameters  '
        },
        :"nbs.external_url_params_captured" => {
          :default => '',
          :public => true,
          :type => String,
          :allowed_from_server => true,
          :description => 'Enable or disable Specifies External  request parameters  '
        },
        :'nbs.action_tracer.enabled' => {
          :default => true,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable action traces'
        },
        :'nbs.action_tracer.action_threshold' => {
          :default => DefaultSource.action_tracer_action_threshold,
          :public => true,
          :type => Fixnum,
          :allowed_from_server => true,
          :description => 'The agent will collect traces for action that exceed this time threshold (in millisecond). Specify a int value or <code><a href="">apdex_f</a></code>.'
        },
        :'nbs.action_tracer.record_sql' => {
          :default => 'obfuscate',
          :public => true,
          :type => String,
          :allowed_from_server => true,
          :description => 'Obfuscation level for SQL queries reported in action trace nodes. Valid options are <code>obfuscated</code>, <code>raw</code>, <code>off</code>.'
        },
        :'nbs.action_tracer.slow_sql' => {
          :default => true,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable collection of slow SQL queries.'
        },
        :'nbs.action_tracer.slow_sql_threshold' => {
          :default =>500,
          :public => true,
          :type => Fixnum,
          :allowed_from_server => true,
          :description => 'The agent will collect traces for slow_sql that exceed this time threshold (in millisecond). Specify a int value or <code><a href="">apdex_f</a></code>.'
        },
        :'nbs.action_tracer.explain_enabled' => {
          :default => true,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable the collection of explain plans in action traces. This setting will also apply to explain plans in Slow SQL traces if slow_sql.explain_enabled is not set separately.'
        },
        :'nbs.action_tracer.explain_threshold' => {
          :default => 500,
          :public => true,
          :type => Fixnum,
          :allowed_from_server => true,
          :description => 'Threshold (in millisecond) above which the agent will collect explain plans. Relevant only when <code><a href="">explain_enabled</a></code> is true.'
        },
        :'nbs.action_tracer.stack_trace_threshold' => {
          :default => 500,
          :public => true,
          :type => Fixnum,
          :allowed_from_server => true,
          :description => 'Threshold (in millisecond) above which the agent will collect stack_trace.'
        },
        :'nbs.action_tracer.nbsua' => {
          :default => true,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable to trace nbs web request'
        },
        :'nbs.transaction_tracer.enabled' => {
          :default => false,
          :public => true,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable transaction traces'
        },
        :'nbs.rum.enabled' => {
          :default => false,
          :public => false,
          :type => Boolean,
          :allowed_from_server => true,
          :description => 'Enable or disable page load timing (sometimes referred to as real user monitoring or RUM).'
        },
        :'nbs.rum.script' => {
          :default => nil,
          :public => false,
          :type => String,
          :allowed_from_server => true,
          :description => 'RUM Script URI'
        },
        :'nbs.rum.sample_ratio' => {
          :default => 1,
          :public => true,
          :type => Fixnum,
          :allowed_from_server => true,
          :description => 'RUM per'
        }
      }.freeze
    end
  end
end
