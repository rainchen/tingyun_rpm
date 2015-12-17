
require 'ting_yun/frameworks/rails'
require 'ting_yun/frameworks/rails3'
require 'ting_yun/frameworks/rails4'


if defined?(::Rails)
  PARENT = case ::Rails::VERSION::MAJOR.to_i
                   when 4
                     TingYun::Frameworks::Rails4
                   when 3
                     TingYun::Frameworks::Rails3
                 end
end

PARENT ||= TingYun::Frameworks::Rails

class TingYun::Frameworks::Test < PARENT
  def env
    'test'
  end

  def app
    if defined?(::Rails) && defined?(::Rails::VERSION)
      if ::Rails::VERSION::MAJOR.to_i == 4
        :rails4
      elsif ::Rails::VERSION::MAJOR.to_i == 3
        :rails3
      else
        :rails
      end
    else
      :test
    end
  end


end