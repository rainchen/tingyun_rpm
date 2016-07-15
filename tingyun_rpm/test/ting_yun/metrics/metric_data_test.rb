require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'test_helper'))
require 'ting_yun/metrics/metric_data'
require 'ting_yun/metrics/metric_spec'
require 'ting_yun/metrics/stats'



module TingYun::Metrics
  class MetricDateTest < Minitest::Test
    def test_initialize_basic
      spec = mock('metric_spec')
      stats = mock('stats')
      metric_id = mock('metric_id')
      md = TingYun::Metrics::MetricData.new(spec, stats, metric_id)
      assert_equal spec, md.metric_spec
      assert_equal stats, md.stats
      assert_equal metric_id, md.metric_id
    end

    def test_eql_basic
      spec = mock('metric_spec')
      stats = mock('stats')
      metric_id = mock('metric_id')
      md1 = TingYun::Metrics::MetricData.new(spec, stats, metric_id)
      md2 = TingYun::Metrics::MetricData.new(spec, stats, metric_id)
      assert(md1.eql?(md2), "The example metric data objects should be eql?: #{md1.inspect} #{md2.inspect}")
      assert(md2.eql?(md1), "The example metric data objects should be eql?: #{md1.inspect} #{md2.inspect}")
    end

    def test_eql_unequal_specs
      spec = mock('metric_spec')
      other_spec = mock('other_spec')
      stats = mock('stats')
      metric_id = mock('metric_id')
      md1 = TingYun::Metrics::MetricData.new(spec, stats, metric_id)
      md2 = TingYun::Metrics::MetricData.new(other_spec, stats, metric_id)
      assert(!md1.eql?(md2), "The example metric data objects should not be eql?: #{md1.inspect} #{md2.inspect}")
      assert(!md2.eql?(md1), "The example metric data objects should not be eql?: #{md1.inspect} #{md2.inspect}")
    end

    def test_eql_unequal_stats
      spec = mock('metric_spec')
      stats = mock('stats')
      other_stats = mock('other_stats')
      metric_id = mock('metric_id')
      md1 = TingYun::Metrics::MetricData.new(spec, stats, metric_id)
      md2 = TingYun::Metrics::MetricData.new(spec, other_stats, metric_id)
      assert(!md1.eql?(md2), "The example metric data objects should not be eql?: #{md1.inspect} #{md2.inspect}")
      assert(!md2.eql?(md1), "The example metric data objects should not be eql?: #{md1.inspect} #{md2.inspect}")
    end

    def test_eql_unequal_metric_ids_dont_matter
      spec = mock('metric_spec')
      stats = mock('stats')
      metric_id = mock('metric_id')
      other_metric_id = mock('other_metric_id')
      md1 = TingYun::Metrics::MetricData.new(spec, stats, metric_id)
      md2 = TingYun::Metrics::MetricData.new(spec, stats, other_metric_id)
      assert(md1.eql?(md2), "The example metric data objects should be eql? with different metric_ids: #{md1.inspect} #{md2.inspect}")
      assert(md2.eql?(md1), "The example metric data objects should be eql? with different metric_ids: #{md1.inspect} #{md2.inspect}")
    end

    def test_hash
      spec = mock('metric_spec')
      stats = mock('stats')
      metric_id = mock('metric_id')
      md1 = TingYun::Metrics::MetricData.new(spec, stats, metric_id)
      assert((spec.hash ^ stats.hash) == md1.hash, "expected #{spec.hash ^ stats.hash} to equal #{md1.hash}")
    end


    if {}.respond_to?(:to_json)
      def test_to_json_no_metric_id
        md = TingYun::Metrics::MetricData.new(TingYun::Metrics::MetricSpec.new('Custom/test/method', ''), TingYun::Metrics::Stats.new, nil)
        json = md.to_json
        assert(json.include?('"Custom/test/method"'), "should include the metric spec in the json")
        assert(json.include?('"metric_id":null}'), "should have a null metric_id")
      end

      def test_to_json_with_metric_id
        md = TingYun::Metrics::MetricData.new(TingYun::Metrics::MetricSpec.new('Custom/test/method', ''), TingYun::Metrics::Stats.new, 12345)
        assert_equal('{"metric_spec":null,"stats":{"total_exclusive_time":0.0,"min_call_time":0.0,"call_count":0,"sum_of_squares":0.0,"total_call_time":0.0,"max_call_time":0.0},"metric_id":12345}', md.to_json, "should not include the metric spec and should have a metric_id")
      end
    else
      puts "Skipping tests in #{__FILE__} because Hash#to_json not available"
    end

    def test_to_s_with_metric_spec
      md = TingYun::Metrics::MetricData.new(TingYun::Metrics::MetricSpec.new('Custom/test/method', ''), TingYun::Metrics::Stats.new, 12345)
      assert_equal('Custom/test/method(): [ 0 calls 0.0000s / 0.0000s ex]', md.to_s, "should not include the metric id and should include the metric spec")
    end

    def test_to_s_without_metric_spec
      md = TingYun::Metrics::MetricData.new(nil, TingYun::Metrics::Stats.new, 12345)
      assert_equal('12345: [ 0 calls 0.0000s / 0.0000s ex]', md.to_s, "should include the metric id and not have a metric spec")
    end

    def test_to_collector_array_with_spec
      stats = TingYun::Metrics::Stats.new
      stats.record_data_point(1.0)
      stats.record_data_point(2.0, 1.0)
      md = TingYun::Metrics::MetricData.new(TingYun::Metrics::MetricSpec.new('Custom/test/method', 'parent'),
                                    stats, nil)
      expected = [ {'name' => 'Custom/test/method', 'parent' => 'parent'},
                   [2, 3.0, 2.0, 2.0, 1.0, 5.0] ]
      assert_equal expected, md.to_collector_array
    end

    def test_to_collector_array_with_spec_and_id
      stats = TingYun::Metrics::Stats.new
      stats.record_data_point(1.0)
      stats.record_data_point(2.0, 1.0)
      md = TingYun::Metrics::MetricData.new(TingYun::Metrics::MetricSpec.new('Custom/test/method', 'scope'),
                                    stats, 1234)
      expected = [ 1234, [2, 3.0, 2.0, 2.0, 1.0, 5.0] ]
      assert_equal expected, md.to_collector_array
    end

    def test_to_collector_array_with_id
      stats = TingYun::Metrics::Stats.new
      stats.record_data_point(1.0)
      stats.record_data_point(2.0, 1.0)
      md = TingYun::Metrics::MetricData.new(nil, stats, 1234)
      expected = [ 1234, [2, 3.0, 2.0, 2.0, 1.0, 5.0] ]
      assert_equal expected, md.to_collector_array
    end


    def test_to_collector_array_with_rationals
      stats = TingYun::Metrics::Stats.new
      stats.call_count = Rational(1, 1)
      stats.total_call_time = Rational(2, 1)
      stats.total_exclusive_time = Rational(3, 1)
      stats.min_call_time = Rational(4, 1)
      stats.max_call_time = Rational(5, 1)
      stats.sum_of_squares = Rational(6, 1)

      md = TingYun::Metrics::MetricData.new(nil, stats, 1234)
      expected = [1234, [1, 2.0, 3.0, 5.0, 4.0, 6.0]]
      assert_equal expected, md.to_collector_array
    end



  end
end