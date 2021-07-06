# frozen_string_literal: true

module SuperSettings
  module Attributes
    class UnknownAttributeError < StandardError
    end

    def initialize(attributes = nil)
      self.attributes = attributes if attributes
    end

    def attributes=(values)
      values.each do |name, value|
        if respond_to?("#{name}=", true)
          send("#{name}=", value)
        else
          raise UnknownAttributeError.new("unknown attribute #{name.to_s.inspect} for #{self.class}")
        end
      end
    end
  end
end
