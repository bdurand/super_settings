# frozen_string_literal: true

module SuperSettings
  class BooleanParser
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
