# frozen_string_literal: true

module SuperSettings
  module Storage
    # Generic class that can be extended to represent a history record for a setting in memory.
    class HistoryAttributes
      include SuperSettings::Attributes

      attr_accessor :key, :value, :changed_by
      attr_writer :deleted
      attr_reader :created_at

      def initialize(*)
        @key = nil
        @value = nil
        @changed_by = nil
        @created_at = nil
        @deleted = false
        super
      end

      def created_at=(val)
        @created_at = TimePrecision.new(val).time
      end

      def deleted?
        !!@deleted
      end
    end
  end
end
