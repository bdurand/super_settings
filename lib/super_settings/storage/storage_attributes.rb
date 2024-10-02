# frozen_string_literal: true

module SuperSettings
  module Storage
    # Generic class that can be extended to represent a setting in memory.
    class StorageAttributes
      include SuperSettings::Storage

      attr_reader :key, :raw_value, :description, :value_type, :updated_at, :created_at

      def initialize(attributes = nil)
        @key = nil
        @raw_value = nil
        @description = nil
        @value_type = nil
        @deleted = false
        @updated_at = nil
        @created_at = nil
        @persisted = false
        super
      end

      def key=(value)
        @key = (Coerce.blank?(value) ? nil : value.to_s)
      end

      def raw_value=(value)
        @raw_value = (Coerce.blank?(value) ? nil : value.to_s)
      end

      def value_type=(value)
        @value_type = (Coerce.blank?(value) ? nil : value.to_s)
      end

      def description=(value)
        @description = (Coerce.blank?(value) ? nil : value.to_s)
      end

      def updated_at=(value)
        @updated_at = SuperSettings::Coerce.time(value)
      end

      def created_at=(value)
        @created_at = SuperSettings::Coerce.time(value)
      end

      def deleted?
        !!@deleted
      end

      def deleted=(val)
        @deleted = !!val
      end

      def persisted?
        !!@persisted
      end

      def persisted=(val)
        @persisted = !!val
      end
    end
  end
end
