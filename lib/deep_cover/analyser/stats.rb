module DeepCover
  class Analyser::StatsBase
    VALUES =  [:executed, :not_executed, :not_executable, :ignored] # All are exclusive
    attr_reader *VALUES

    def to_h
      VALUES.map do |val|
        [val, public_send(val)]
      end.to_h
    end

    def initialize(executed: raise, not_executed: raise, not_executable: raise, ignored: raise)
      @executed, @not_executed, @not_executable, @ignored = executed, not_executed, not_executable, ignored
      freeze
    end

    def +(other)
      self.class.new(to_h.merge(other.to_h) {|k, a, b| a + b})
    end

    def total
      to_h.values.inject(:+)
    end
  end
  memoize Analyser::StatsBase

  class Analyser::Stats < Analyser::StatsBase
    def percent(decimals = 2)
      Analyser::StatsBase.new(to_h.transform_values{|v| (100 * v).fdiv(total).round(decimals) })
    end
  end
  memoize Analyser::Stats
end
