# frozen_string_literal: true

module SuperSettings
  # Helper class for truncating timestamps to a specific precision. This is used by storage engines
  # to ensure that timestamps are stored and compared with the same precision.
  class TimePrecision
    attr_reader :time

    def initialize(time, precision = :microsecond)
      raise ArgumentError.new("Invalid precision: #{precision}") unless valid_precision?(precision)

      @time = time_with_precision(time.to_f, precision) if time
    end

    def to_f
      @time.to_f
    end

    private

    def valid_precision?(precision)
      [:microsecond, :millisecond].include?(precision)
    end

    def time_with_precision(timestamp, precision)
      usec = (timestamp % 1) * 1_000_000.0
      if precision == :millisecond
        milliseconds = (usec / 1000.0).round(3).floor
        Time.at(timestamp.to_i, milliseconds, :millisecond).utc
      else
        microseconds = usec.round
        Time.at(timestamp.to_i, microseconds, :microsecond).utc
      end
    end
  end
end
