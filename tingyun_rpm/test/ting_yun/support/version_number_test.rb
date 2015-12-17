require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/support/version_number'

module TingYun::Support
  class VersionNumberTest < Minitest::Test

    def test_comparison__first
      versions = %w[1.0.0 0.1.0 0.0.1 10.0.1 1.10.0].map {|s| TingYun::Support::VersionNumber.new s }
      assert_equal %w[0.0.1 0.1.0 1.0.0 1.10.0 10.0.1], versions.sort.map(&:to_s)
      v0 = TingYun::Support::VersionNumber.new '1.2.3'
      v1 = TingYun::Support::VersionNumber.new '1.2.2'
      v3 = TingYun::Support::VersionNumber.new '1.2.2'
      assert v0 > v1
      assert v1 == v1
      assert v1 == v3
    end

    def test_comparison__second
      v0 = TingYun::Support::VersionNumber.new '1.2.0'
      v1 = TingYun::Support::VersionNumber.new '2.2.2'
      v3 = TingYun::Support::VersionNumber.new '1.1.2'
      assert v0 < v1
      assert v1 > v3
      assert v3 < v0
    end
    def test_bug
      v0 = TingYun::Support::VersionNumber.new '2.8.999'
      v1 = TingYun::Support::VersionNumber.new '2.9.10'
      assert v1 > v0
      assert v0 <= v1
    end

    def test_sort
      values = %w[1.1.1
                1.1.99
                1.1.999
                2.0.6
                2.6.5
                2.7
                2.7.1
                2.7.2
                2.7.2.0
                3
                999]
      assert_equal values, values.map{|v| TingYun::Support::VersionNumber.new v}.sort.map(&:to_s)
    end

    def test_prerelease
      v0 = TingYun::Support::VersionNumber.new '1.2.0.beta'
      assert_equal [1,2,0,'beta'], v0.parts
      assert v0 > '1.1.9.0'
      assert v0 > '1.1.9.alpha'
      assert v0 > '1.2.0.alpha'
      assert v0 == '1.2.0.beta'
      assert v0 < '1.2.1'
      assert v0 < '1.2.0'
      assert v0 < '1.2.0.c'
      assert v0 < '1.2.0.0'

    end

    def test_compare_string
      v0 = TingYun::Support::VersionNumber.new '1.2.0'
      v1 = TingYun::Support::VersionNumber.new '2.2.2'
      v3 = TingYun::Support::VersionNumber.new '1.1.2'
      assert v0 < '2.2.2'
      assert v1 > '1.1.2'
      assert v3 < '1.2.0'
      assert v0 == '1.2.0'
    end

    def test_string
      assert_equal '1.2.0', TingYun::Support::VersionNumber.new('1.2.0').to_s
      assert_equal '1.2', TingYun::Support::VersionNumber.new('1.2').to_s
    end

  end
end