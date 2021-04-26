# frozen_string_literal: true

# Backport of logic in ActiveModel::Types::BooleanParser.
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
