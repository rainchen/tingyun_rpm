# encoding: utf-8
require 'ting_yun/vm/snapshot'
require 'ting_yun/support/language_support'
module TingYun
  module Vm
    class MriVM

      def snapshot
        snap = Snapshot.new
        gather_stats(snap)
        snap
      end

      def gather_stats(snap)
        gather_gc_stats(snap)
        gather_gc_time(snap)
        gather_ruby_vm_stats(snap)
        gather_thread_stats(snap)
      end

      def gather_gc_stats(snap)
        if supports?(:gc_runs)
          snap.gc_runs = GC.count
        end

        if GC.respond_to?(:stat)
          gc_stats = GC.stat
          snap.total_allocated_object = gc_stats[:total_allocated_objects] || gc_stats[:total_allocated_object]
          snap.major_gc_count = gc_stats[:major_gc_count]
          snap.minor_gc_count = gc_stats[:minor_gc_count]
          snap.heap_live = gc_stats[:heap_live_slots] || gc_stats[:heap_live_slot] || gc_stats[:heap_live_num]
          snap.heap_free = gc_stats[:heap_free_slots] || gc_stats[:heap_free_slot] || gc_stats[:heap_free_num]
        end
      end

      def gather_gc_time(snap)
        if supports?(:gc_total_time)
          snap.gc_total_time = TingYun::Agent.instance.monotonic_gc_profiler.total_time_s
        end
      end

      def gather_ruby_vm_stats(snap)
        if supports?(:method_cache_invalidations)
          vm_stats = RubyVM.stat
          snap.method_cache_invalidations = vm_stats[:global_method_state]
          snap.constant_cache_invalidations = vm_stats[:global_constant_state]
          snap.class_serial = vm_stats[:class_serial]
        end
      end

      def gather_thread_stats(snap)
        snap.thread_count = Thread.list.size
      end


      def support?(key)
        case key
          when :gc_runs
            RUBY_VERSION >= '1.9.2'
          when :gc_total_time
            TingYun::LanguageSupport.gc_profiler_enabled?
          when :total_allocated_object
            RUBY_VERSION >= '2.0.0'
          when :major_gc_count
            RUBY_VERSION >= '2.1.0'
          when :minor_gc_count
            RUBY_VERSION >= '2.1.0'
          when :heap_live
            RUBY_VERSION >= '1.9.3'
          when :heap_free
            RUBY_VERSION >= '1.9.3'
          when :method_cache_invalidations
            RUBY_VERSION >= '2.1.0'
          when :constant_cache_invalidations
            RUBY_VERSION >= '2.1.0'
          when :thread_count
            true
          else
            false
        end
      end
    end
  end
end

