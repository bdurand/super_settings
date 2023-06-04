# frozen_string_literal: true

require "set"

module SuperSettings
  # Utility functions for coercing values to other data types.
  class Coerce
    # rubocop:disable Lint/BooleanSymbol
    FALSE_VALUES = Set.new([
      false, 0,
      "0", :"0",
      "f", :f,
      "F", :F,
      "false", :false,
      "FALSE", :FALSE,
      "off", :off,
      "OFF", :OFF
    ]).freeze
    # rubocop:enable Lint/BooleanSymbol

    class << self
      # Cast variations of booleans (i.e. "true", "false", 1, 0, etc.) to actual boolean objects.
      #
      # @param value [Object]
      # @return [Boolean]
      def boolean(value)
        if value == false
          false
        elsif blank?(value)
          nil
        else
          !FALSE_VALUES.include?(value)
        end
      end

      # Cast a value to a Time object.
      #
      # @param value [Object]
      # @return [Time]
      def time(value)
        value = nil if value.nil? || value.to_s.empty?
        return nil if value.nil?
        time = if value.is_a?(Numeric)
          Time.at(value)
        elsif value.respond_to?(:to_time)
          value.to_time
        else
          Time.parse(value.to_s)
        end
        if time.respond_to?(:in_time_zone) && Time.respond_to?(:zone)
          time = time.in_time_zone(Time.zone)
        end
        time
      end

      # @return [Boolean] true if the value is nil or empty.
      def blank?(value)
        return true if value.nil?
        if value.respond_to?(:empty?)
          value.empty?
        else
          value.to_s.empty?
        end
      end

      # @return [Boolean] true if the value is not nil and not empty.
      def present?(value)
        !blank?(value)
      end
    end
  end
end
