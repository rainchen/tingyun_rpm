# encoding: utf-8

module TingYun
  module Agent
    class TracedMethodFrame
      attr_reader :tag
      attr_accessor :name, :start_time, :children_time
      def initialize(tag, start_time)
        @tag = tag
        @start_time = start_time
        @children_time = 0
      end
    end

    class TracedMethodStack
      def initialize
        @stack = []
      end

      def push_frame(state, tag, time = Time.now.to_f)
        frame = TracedMethodFrame.new(tag, time)
        @stack.push frame
        frame
      end

      def pop_frame(state, expected_frame, name, time, deduct_call_time_from_parent=true)
        frame = fetch_matching_frame(expected_frame)

        note_children_time(frame, time, deduct_call_time_from_parent)

        frame.name = name
        frame
      end

      def fetch_matching_frame(expected_frame)
        while frame = @stack.pop
          if frame == expected_frame
            return frame
          else
            TingYun::Agent.logger.info("Unexpected frame in traced method stack: #{frame.inspect} expected to be #{expected_frame.inspect}")
            TingYun::Agent.logger.debug do
              ["Backtrace for unexpected frame: ", caller.join("\n")]
            end
          end
        end

        raise "Frame not found in blame stack: #{expected_frame.inspect}"
      end

      def note_children_time(frame, time, deduct_call_time_from_parent)
        if !@stack.empty?
          if deduct_call_time_from_parent
            @stack.last.children_time += (time - frame.start_time)*1000
          else
            @stack.last.children_time += frame.children_time
          end
        end
      end

      def clear
        @stack.clear
      end

      def empty?
        @stack.empty?
      end
    end
  end
end
