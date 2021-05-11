# frozen_string_literal: true

# Cast variations of booleans (i.e. "true", "false", 1, 0, etc.) to actual boolean objects.
module SuperSettings
  class BooleanParser
    # rubocop:disable Lint/BooleanSymbol
    FALSE_VALUES = [
      false, 0,
      "0", :"0",
      "f", :f,
      "F", :F,
      "false", :false,
      "FALSE", :FALSE,
      "off", :off,
      "OFF", :OFF
    ].to_set.freeze
    # rubocop:enable Lint/BooleanSymbol

    class << self
      # Cast a value to a boolean
      # @param value [Object]
      # @return [Boolean]
      def cast(value)
        if value == false
          false
        elsif value.blank?
          nil
        else
          !FALSE_VALUES.include?(value)
        end
      end
    end
  end
end
