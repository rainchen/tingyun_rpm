# encoding: utf-8
# This file is distributed under Ting Yun's license terms.


require 'forwardable'

module TingYun
  module Configuration

    # Helper since default Procs are evaluated in the context of this module
    def self.value_of(key)
      # Proc.new do
      #   NewRelic::Agent.config[key]
      # end
    end

    class Boolean;
    end

    class DefaultSource
      attr_reader :defaults

      extend Forwardable
      def_delegators :@defaults, :keys, :has_key?, :[]

      def initialize
        @defaults = default_values
      end

      def default_values
        result = {}
        ::TingYun::Configuration::DEFAULTS.each do |key, value|
          result[key] = value[:default]
        end
        result
      end

      def self.auto_app_naming
        Proc.new { true }
      end

      def self.dispatcher
        Proc.new { :dispatcher }
      end

      def self.agent_enabled
        # Proc.new {
        #   TingYun::Agent.config[:enabled] &&
        #   (TingYun::Agent.config[:developer_mode] || TingYun::Agent.config[:monitor_mode]) &&
        #   TingYun::Agent::Autostart.agent_should_start?
        # }
        Proc.new { true }
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


      def self.config_search_paths
        Proc.new {
          paths = [
              File.join("config", "tingyun.yml"),
              File.join("tingyun.yml")
          ]

          # if TingYun::Agent.instance.root
          #   paths << File.join(NewRelic::Control.instance.root, "config", "tingyun.yml")
          #   paths << File.join(NewRelic::Control.instance.root, "tingyun.yml")
          # end

          if ENV["HOME"]
            paths << File.join(ENV["HOME"], ".tingyun", "tingyun.yml")
            paths << File.join(ENV["HOME"], "tingyun.yml")
          end

          # If we're packaged for warbler, we can tell from GEM_HOME
          if ENV["GEM_HOME"] && ENV["GEM_HOME"].end_with?(".jar!")
            app_name = File.basename(ENV["GEM_HOME"], ".jar!")
            paths << File.join(ENV["GEM_HOME"], app_name, "config", "tingyun.yml")
          end

          paths
        }
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
        :license_key => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Your Ting Yun <a href="">license key</a>.'
        },
        :agent_enabled => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable the agent.'
        },
        :app_name => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Semicolon-delimited list of Naming your application.'
        },
        :auto_app_naming => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable to identify the application name'
        },
        :agent_log_file_path => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Specifies a path to the audit log file '
        },
        :agent_log_file_name => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'log  filename.'
        },
        :config_search_paths => {
            :default => DefaultSource.config_search_paths,
            :public => false,
            :type => Array,
            :allowed_from_server => false,
            :description => "An array of candidate locations for the agent's configuration file."
        },
        :dispatcher => {
            :default => DefaultSource.dispatcher,
            :public => false,
            :type => Symbol,
            :allowed_from_server => false,
            :description => 'Autodetected application component that reports metrics to Ting YUN.'
        },
        :framework => {
            :default => :framework,
            :public => false,
            :type => Symbol,
            :allowed_from_server => false,
            :description => 'Autodetected application framework used to enable framework-specific functionality.'
        },
        :monitor_mode => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable the transmission of data to the collector.'
        },
        :audit_mode => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable to log the transmission-date for developer'
        },
        :agent_log_level => {
            :default => 'info',
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Log level for agent logging: critical, error, warning, info, verbose or debug.'
        },
        :proxy_host => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Defines a host for communicating with Ting Yun via a proxy server.'
        },
        :proxy_port => {
            :default => 8080,
            :allow_nil => true,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Defines a port for communicating with Ting Yun via a proxy server.'
        },
        :proxy_user => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :description => 'Defines a user for communicating with Ting Yun via a proxy server.'
        },
        :proxy_password => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => String,
            :allowed_from_server => false,
            :exclude_from_reported_settings => true,
            :description => 'Defines a password for communicating with Ting Yun via a proxy server.'
        },
        :host => {
            :default => 'dc1.networkbench.com',
            :public => false,
            :type => String,
            :allowed_from_server => false,
            :description => "URI for the Ting Yun data collection service."
        },
        :port => {
            :default => nil,
            :allow_nil => true,
            :public => false,
            :type => Fixnum,
            :allowed_from_server => false,
            :description => 'Port for the Ting Yun data collection service.'
        },
        :ssl => {
            :default => true,
            :allow_nil => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable SSL for transmissions to the Ting Yun'
        },
        :'action_tracer.log_sql' => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable(write into log file) collection of SQL queries.'
        },
        :daemon_debug => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable(result-json contains key-id) debug mode'
        },
        :urls_captured => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => true,
            :description => 'Enable or disable Specifies url'
        },
        :auto_action_naming => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable to use default name '
        },
        :capture_params => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable the capture of HTTP request parameters to be attached to transaction traces and traced errors.'
        },
        :ignored_params => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => true,
            :description => 'Enable or disable Specifies HTTP request parameters '
        },
        :"error_collector.enabled" => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable recording of traced errors and error count metrics.'
        },
        :"error_collector.ignored_status_codes" => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => true,
            :description => 'Enable or disable Specifies HTTP response code '
        },
        :web_action_uri_params_captured => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => true,
            :description => 'Enable or disable Specifies WebAction request parameters  '
        },
        :external_url_params_captured => {
            :default => '',
            :public => true,
            :type => String,
            :allowed_from_server => true,
            :description => 'Enable or disable Specifies External  request parameters  '
        },
        :'action_tracer.enabled' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable action traces'
        },
        :'action_tracer.action_threshold' => {
            :default => nil,
            :allow_nil => true,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => true,
            :description => 'The agent will collect traces for action that exceed this time threshold (in millisecond). Specify a int value or <code><a href="">apdex_f</a></code>.'
        },
        :'action_tracer.record_sql' => {
            :default => 'obfuscate',
            :public => true,
            :type => String,
            :allowed_from_server => true,
            :description => 'Obfuscation level for SQL queries reported in action trace nodes. Valid options are <code>obfuscated</code>, <code>raw</code>, <code>off</code>.'
        },
        :'action_tracer.slow_sql' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable collection of slow SQL queries.'
        },
        :'action_tracer.slow_sql_threshold' => {
            :default => 500,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => true,
            :description => 'The agent will collect traces for slow_sql that exceed this time threshold (in millisecond). Specify a int value or <code><a href="">apdex_f</a></code>.'
        },
        :'action_tracer.explain_enabled' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable the collection of explain plans in action traces. This setting will also apply to explain plans in Slow SQL traces if slow_sql.explain_enabled is not set separately.'
        },
        :'action_tracer.explain_threshold' => {
            :default => 500,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => true,
            :description => 'Threshold (in millisecond) above which the agent will collect explain plans. Relevant only when <code><a href="">explain_enabled</a></code> is true.'
        },
        :'action_tracer.stack_trace_threshold' => {
            :default => 500,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => true,
            :description => 'Threshold (in millisecond) above which the agent will collect stack_trace.'
        },
        :'action_tracer.nbsua' => {
            :default => true,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable to trace nbs web request'
        },
        :'transaction_tracer.enabled' => {
            :default => false,
            :public => true,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable transaction traces'
        },
        :'rum.enabled' => {
            :default => false,
            :public => false,
            :type => Boolean,
            :allowed_from_server => true,
            :description => 'Enable or disable page load timing (sometimes referred to as real user monitoring or RUM).'
        },
        :'rum.script' => {
            :default => nil,
            :allow_nil => true,
            :public => false,
            :type => String,
            :allowed_from_server => true,
            :description => 'RUM Script URI'
        },
        :'rum.sample_ratio' => {
            :default => 1,
            :public => true,
            :type => Fixnum,
            :allowed_from_server => true,
            :description => 'RUM per'
        },
        :send_environment_info => {
            :default => true,
            :public => false,
            :type => Boolean,
            :allowed_from_server => false,
            :description => 'Enable or disable transmission of application environment information to the Ting Yun data collection service.'
        }
    }.freeze
  end
end
