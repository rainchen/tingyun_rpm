require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/metrics/stats'


module TingYun::Metrics
  class StatsTest < Minitest::Test

    def test_update_totals
      attrs = [:total_call_time, :total_exclusive_time, :sum_of_squares]
      a = TingYun::Metrics::Stats.new
      b = TingYun::Metrics::Stats.new

      attrs.each do |attr|
        a.send("#{attr}=", 2)
        b.send("#{attr}=", 3)
      end

      c = a.merge(b)

      attrs.each do |attr|
        assert_equal(5, c.send(attr))
      end


    end


    def test_simple
      stats = TingYun::Metrics::Stats.new
      validate stats, 0, 0, 0, 0

      assert_equal stats.call_count,0
      stats.trace_call 10
      stats.trace_call 20
      stats.trace_call 30

      validate stats, 3, (10+20+30), 10, 30
    end

    def test_to_s
      s1 = TingYun::Metrics::Stats.new
      s1.trace_call 10
      assert_equal('[ 1 calls 10.0000s / 10.0000s ex]', s1.to_s)
    end

    def test_apdex_recording
      s = TingYun::Metrics::Stats.new

      s.record_apdex(:apdex_s, 1)
      s.record_apdex(:apdex_t, 1)

      s.record_apdex(:apdex_f, 1)
      s.record_apdex(:apdex_t, 1)

      assert_equal(1, s.apdex_s)
      assert_equal(1, s.apdex_f)
      assert_equal(2, s.apdex_t)
    end

    def test_merge
      s1 = TingYun::Metrics::Stats.new
      s2 = TingYun::Metrics::Stats.new

      s1.trace_call 10
      s2.trace_call 20
      s2.freeze

      validate s2, 1, 20, 20, 20
      s3 = s1.merge s2
      validate s3, 2, (10+20), 10, 20
      validate s1, 1, 10, 10, 10
      validate s2, 1, 20, 20, 20

      s1.merge! s2
      validate s1, 2, (10+20), 10, 20
      validate s2, 1, 20, 20, 20
    end


    def test_merge_with_exclusive
      s1 = TingYun::Metrics::Stats.new
      s2 = TingYun::Metrics::Stats.new

      s1.trace_call 10, 5
      s2.trace_call 20, 10
      s2.freeze

      validate s2, 1, 20, 20, 20, 10
      s3 = s1.merge s2
      validate s3, 2, (10+20), 10, 20, (10+5)
      validate s1, 1, 10, 10, 10, 5
      validate s2, 1, 20, 20, 20, 10

      s1.merge! s2
      validate s1, 2, (10+20), 10, 20, (5+10)
      validate s2, 1, 20, 20, 20, 10
    end


    def test_freeze
      s1 = TingYun::Metrics::Stats.new

      s1.trace_call 10
      s1.freeze

      begin
        # the following should throw an exception because s1 is frozen
        s1.trace_call 20
        assert false
      rescue StandardError
        assert s1.frozen?
        validate s1, 1, 10, 10, 10
      end
    end


    def test_sum_of_squares_merge
      s1 = TingYun::Metrics::Stats.new
      s1.trace_call 4
      s1.trace_call 7

      s2 = TingYun::Metrics::Stats.new
      s2.trace_call 13
      s2.trace_call 16

      s3 = s1.merge(s2)

      assert_equal(s1.sum_of_squares, 4*4 + 7*7)
      assert_equal(s3.sum_of_squares, 4*4 + 7*7 + 13*13 + 16*16, "check sum of squares")
    end

    if RUBY_VERSION >= '1.9'
      require "json"
      def test_to_json_enforces_float_values
        s1 = TingYun::Metrics::Stats.new
        s1.trace_call 3.to_r
        s1.trace_call 7.to_r

        assert_equal 3.0, ::JSON.load(s1.to_json)['min_call_time']
      end
    end


    private
    def validate (stats, count, total, min, max, exclusive = nil)
      assert_equal count, stats.call_count
      assert_equal total, stats.total_call_time
      assert_equal min,   stats.min_call_time
      assert_equal max,   stats.max_call_time
      assert_equal exclusive, stats.total_exclusive_time if exclusive
    end

  end
end