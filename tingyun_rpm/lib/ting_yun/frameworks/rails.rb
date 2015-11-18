# encoding: utf-8

require 'ting_yun/frameworks/ruby'

module TingYun
  module Frameworks
    # noinspection ALL
    class Rails < TingYun::Frameworks::Ruby

      def env
        @evn ||= RAILS_ENV.dup
      end

      def root
        root = rails_root.to_s.empty? ? super : rails_root.to_s
      end

      # noinspection Rails3Deprecated,Rails3Deprecated
      def rails_root
        RAILS_ROOT if defined?(RAILS_ROOT)
      end

      def rails_config
        if defined?(::Rails) && ::Rails.respond_to?(:configuration)
          ::Rails.configuration
        else
          @config
        end
      end

      def init_config(options = {})
        @config = options[:config]
      end

    end
  end
end