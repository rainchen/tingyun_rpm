# encoding: utf-8


require 'ting_yun/support/language_support'

module TingYun
  # A singleton for shared generic helper methods
  module Helper
    extend self

    # confirm a string is correctly encoded (in >= 1.9)
    # If not force the encoding to ASCII-8BIT (binary)
    if TingYun::Support::LanguageSupport.supports_string_encodings?
      def correctly_encoded(string)
        return string unless string.is_a? String
        # The .dup here is intentional, since force_encoding mutates the target,
        # and we don't know who is going to use this string downstream of us.
        string.valid_encoding? ? string : string.dup.force_encoding("ASCII-8BIT")
      end
    else
      #noop
      def correctly_encoded(string)
        string
      end
    end

    def instance_method_visibility(klass, method_name)
      if klass.private_instance_methods.map{|s|s.to_sym}.include? method_name.to_sym
        :private
      elsif klass.protected_instance_methods.map{|s|s.to_sym}.include? method_name.to_sym
        :protected
      else
        :public
      end
    end

    def instance_methods_include?(klass, method_name)
      method_name_sym = method_name.to_sym
      (
      klass.instance_methods.map{ |s| s.to_sym }.include?(method_name_sym)          ||
          klass.protected_instance_methods.map{ |s|s.to_sym }.include?(method_name_sym) ||
          klass.private_instance_methods.map{ |s|s.to_sym }.include?(method_name_sym)
      )
    end

    def time_to_millis(time)
      def time_to_millis(time)
        mtime = (time.to_f * 1000).round
        mtime > 0 ? mtime : mtime.to_f * 1000
      end
    end

    def milliseconds_to_seconds(milliseconds)
      milliseconds / 1000.0
    end
  end
end
