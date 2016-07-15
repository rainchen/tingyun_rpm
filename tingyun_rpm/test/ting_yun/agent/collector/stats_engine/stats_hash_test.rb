
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', '..', '..','test_helper'))
require 'ting_yun/agent/collector/stats_engine/stats_hash'
require 'ting_yun/metrics/metric_spec'

module TingYun::Agent::Collector
  class StatsHashTest <  MiniTest::Test
    def setup
      @hash = TingYun::Agent::Collector::StatsHash.new
    end

    def test_creates_default_entries
      stats = @hash[TingYun::Metrics::MetricSpec.new('a/b/c/d')]
      assert_kind_of(TingYun::Metrics::Stats, stats)
    end

    def test_record_accpets_single_metric_spec
      spec = TingYun::Metrics::MetricSpec.new('foo/bar')
      stats = @hash[spec]
      stats.expects(:record_data_point).with(42, 42)
      @hash.record(spec,42)
    end

    def test_record_accepts_multiple_metric_specs
      spec1 = TingYun::Metrics::MetricSpec.new('foo/bar', 'scope1')
      spec2 = TingYun::Metrics::MetricSpec.new('foo/bar', 'scope2')
      stats1 = @hash[spec1]
      stats2 = @hash[spec2]
      stats1.expects(:record_data_point).with(42, 42)
      stats2.expects(:record_data_point).with(42, 42)
      @hash.record([spec1, spec2], 42)
    end

    def test_record_accepts_single_metric_spec_with_block
      spec = TingYun::Metrics::MetricSpec.new('foo')
      stats = @hash[spec]
      stats.expects(:do_stuff)
      @hash.record(spec) do |s|
        s.do_stuff
      end
    end

    def test_record_accepts_multiple_metric_specs_with_block
      specs = [
          TingYun::Metrics::MetricSpec.new('foo'),
          TingYun::Metrics::MetricSpec.new('bar')
      ]
      stats = specs.map { |spec| @hash[spec] }
      stats.each { |stat| stat.expects(:do_stuff) }
      @hash.record(specs) do |s|
        s.do_stuff
      end
    end

    def test_record_accepts_stats_value
      spec = TingYun::Metrics::MetricSpec.new('foo')
      other_stats = TingYun::Metrics::Stats.new
      stats = @hash[spec]
      stats.expects(:merge!).with(other_stats)
      @hash.record(spec, other_stats)
    end

    def test_record_accepts_exclusive_time_with_numeric
      spec = TingYun::Metrics::MetricSpec.new('foo')
      stats = @hash[spec]
      stats.expects(:record_data_point).with(42, 10)
      @hash.record(spec, 42, 10)
    end

    def test_record_accepts_apdex_t_with_symbol
      spec = TingYun::Metrics::MetricSpec.new('foo')
      apdex_t = 99
      1.times { @hash.record(spec, :apdex_s, apdex_t) }
      2.times { @hash.record(spec, :apdex_t, apdex_t) }
      3.times { @hash.record(spec, :apdex_f, apdex_t) }
      stats = @hash[spec]
      assert_equal(1, stats.apdex_s)
      assert_equal(2, stats.apdex_t)
      assert_equal(3, stats.apdex_f)
      assert_equal(0, stats.min_call_time)
      assert_equal(99, stats.max_call_time)
      assert_equal(0, stats.sum_of_squares)
    end

    def test_merge_merges
      specs = [
          TingYun::Metrics::MetricSpec.new('foo'),
          TingYun::Metrics::MetricSpec.new('bar'),
          TingYun::Metrics::MetricSpec.new('baz'),
          TingYun::Metrics::MetricSpec.new('baz', 'a_scope')
      ]

      hash1 = TingYun::Agent::Collector::StatsHash.new
      hash1.record(specs[0], 1)
      hash1.record(specs[1], 2)
      hash1.record(specs[2], 3)

      hash2 = TingYun::Agent::Collector::StatsHash.new
      hash2.record(specs[0], 1)
      hash2.record(specs[1], 2)
      hash2.record(specs[3], 3)

      hash1.merge!(hash2)

      assert_equal(4, hash1.to_h.keys.size)
      assert_equal(2, hash1[specs[0]].call_count)
      assert_equal(2, hash1[specs[1]].call_count)
      assert_equal(1, hash1[specs[2]].call_count)
      assert_equal(1, hash1[specs[3]].call_count)
    end

    def test_merge_re_sets_started_at_if_needed
      t0 = Time.at(0)
      t1 = Time.at(100)

      hash0 = TingYun::Agent::Collector::StatsHash.new(t0)
      hash1 = TingYun::Agent::Collector::StatsHash.new(t1)

      hash1.merge!(hash0)
      assert_equal(t0.to_f, hash1.started_at)
    end

    def test_marshal_dump
      @hash.record(TingYun::Metrics::MetricSpec.new('foo'), 1)
      @hash.record(TingYun::Metrics::MetricSpec.new('bar'), 2)
      copy = Marshal.load(Marshal.dump(@hash))
      assert_equal(@hash, copy)
      assert_equal(@hash.started_at, copy.started_at)
    end


  end
end