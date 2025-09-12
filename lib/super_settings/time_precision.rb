# frozen_string_literal: true

module SuperSettings
  # Helper class for truncating timestamps to a specific precision. This is used by storage engines
  # to ensure that timestamps are stored and compared with the same precision.
  class TimePrecision
    # The time value with applied precision.
    attr_reader :time

    # Create a new TimePrecision object.
    #
    # @param time [Time, Numeric] the time to apply precision to
    # @param precision [Symbol] the precision level (:microsecond or :millisecond)
    # @raise [ArgumentError] if precision is not valid
    def initialize(time, precision = :microsecond)
      raise ArgumentError.new("Invalid precision: #{precision}") unless valid_precision?(precision)

      @time = time_with_precision(time.to_f, precision) if time
    end

    # Convert the time to a float.
    #
    # @return [Float] the time as a floating point number
    def to_f
      @time.to_f
    end

    private

    # Check if the precision value is valid.
    #
    # @param precision [Symbol] the precision to validate
    # @return [Boolean] true if precision is valid
    def valid_precision?(precision)
      [:microsecond, :millisecond].include?(precision)
    end

    # Apply the specified precision to a timestamp.
    #
    # @param timestamp [Float] the timestamp to apply precision to
    # @param precision [Symbol] the precision level
    # @return [Time] the time with applied precision
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
