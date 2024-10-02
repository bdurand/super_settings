# frozen_string_literal: true

module SuperSettings
  # Interface to expose mass setting attributes on an object. Setting attributes with a
  # hash will simply call the attribute writers for each key in the hash.
  module Attributes
    def initialize(attributes = nil)
      self.attributes = attributes if attributes
    end

    def attributes=(values)
      values.each do |name, value|
        send(:"#{name}=", value) if respond_to?(:"#{name}=", true)
      end
    end
  end
end
