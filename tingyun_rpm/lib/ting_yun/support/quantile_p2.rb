# encoding: utf-8

module TingYun
  module Support
    class QuantileP2

      def self.support?
        return false if !TingYun::Agent.config[:'nbs.quantile']
        quantile = TingYun::Agent.config[:'nbs.quantile'][1..-2].split(',')
        return false if quantile.size > quantile.uniq.size
        quantile.each do |i|
          return false if i.to_i == 0
          return false if i.to_i.to_s != i
        end
        TingYun::Agent.config[:'nbs.quantile'] = quantile.map(&:to_i).to_s
        return true
      end



      attr_accessor :quartileList, :markers_y, :markers_x, :p2_n, :count
      def initialize(quartileList)
        @quartileList = quartileList.sort!
        @markers_y = Array.new(@quartileList.length * 2 + 3)
        @count = 0
      end

      def initMarkers
        quartile_count = quartileList.length
        marker_count = quartile_count * 2 + 3
        @markers_x = Array.new(marker_count)
        @markers_x[0] = 0.0
        @p2_n = Array.new(markers_y.length)
        (0..quartile_count).times do |i|
          marker = quartileList[i]
          markers_x[i * 2 + 1] = (marker + markers_x[i * 2]) / 2
          markers_x[i * 2 + 2] = marker
        end
        markers_x[marker_count - 2] = (1 + quartileList[quartile_count - 1]) / 2
        markers_x[marker_count - 1] = 1.0
        (0..marker_count).times do |i|
          p2_n[i] = i
        end
      end

      def markers
        if (count < markers_y.length)
          result = Array.new count
          markers = Array.new markers_y.length
          pw_q_copy = markers_y.clone()
          pw_q_copy.sort!

          pw_q_copy.each_index do |i|
            result[i] = pw_q_copy[i]
          end
          (0..pw_q_copy.length).times do |i|
            markers[i] = result[((count - 1) * i * 1.0 / (pw_q_copy.length - 1)).round]
          end
          return markers;
        end
        return markers_y;
      end

      def quadPred(d, i)
        qi = markers_y[i]
        qip1 = markers_y[i + 1]
        qim1 = markers_y[i - 1]
        ni = p2_n[i]
        nip1 = p2_n[i + 1]
        nim1 = p2_n[i - 1]

        a = (ni - nim1 + d) * (qip1 - qi) / (nip1 - ni)
        b = (nip1 - ni - d) * (qi - qim1) / (ni - nim1)
        return qi + (d * (a + b)) / (nip1 - nim1)
      end


      def linPred(d, i)
        qi = markers_y[i]
        qipd = markers_y[i + d]
        ni = p2_n[i]
        nipd = p2_n[i + d]

        return qi + d * (qipd - qi) / (nipd - ni)
      end

      def add(v)
        return unless v.is_a?(Numeric)
        obsIdx = count
        count = count + 1
        if(obsIdx < markers_y.length)
          markers_y[obsIdx] = v
          if (obsIdx == markers_y.length - 1)
            markers_y.sort!
          end
        else
          k = markers_y.find_index {|i| i==v or i>v}
          if k ##in
            if v==markers_y[k] ##exist
              if k == 0##first
                markers_y[0] = v
                k = 1
              elsif k == markers_y.length##last
                k = markers_y.length - 1;
                markers_y[k] = v
              end
            else
              k = k - 1 if k > 0
            end
          else
            k = markers_y.length -1
          end

          (k..p2_n.length).times do |i|
            p2_n[i] += 1
          end

          (1..markers_y.length - 1).times do |i|
            n_ = markers_x[i] * obsIdx
            di = n_ - p2_n[i]
            if ((di-1.0 >=0.000001  && p2_n[i + 1] - p2_n[i] > 1) || ((di+1.0 <=0.000001  && p2_n[i - 1] - p2_n[i] < -1))) do
              d = di < 0 ? -1 : 1
              qi_ = quadPred(d, i)
              if (qi_ < markers_y[i - 1] || qi_ > markers_y[i + 1])
                qi_ = linPred(d, i)
              end
              markers_y[i] = qi_
              p2_n[i] += d
            end
          end
        end
      end
    end
  end
end
