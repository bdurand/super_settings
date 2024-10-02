# frozen_string_literal: true

require "json"

module SuperSettings
  module Storage
    # Implementation of the SuperSettings::Storage model for running unit tests.
    class TestStorage
      # :nocov:

      include Storage

      attr_reader :key, :raw_value, :description, :value_type, :updated_at, :created_at
      attr_accessor :changed_by

      @settings = {}
      @history = {}

      class << self
        attr_reader :settings

        def history(key)
          items = @history[key]
          unless items
            items = []
            @history[key] = items
          end
          items
        end

        def destroy_all
          @settings = {}
          @history = {}
        end

        def all
          settings.values.collect do |attributes|
            setting = new(attributes)
            setting.send(:set_persisted!)
            setting
          end
        end

        def updated_since(time)
          settings.values.select { |attributes| attributes[:updated_at].to_f >= time.to_f }.collect do |attributes|
            setting = new(attributes)
            setting.send(:set_persisted!)
            setting
          end
        end

        def find_by_key(key)
          attributes = settings[key]
          return nil unless attributes
          setting = new(attributes)
          setting.send(:set_persisted!)
          setting unless setting.deleted?
        end

        def last_updated_at
          settings.values.collect { |attributes| attributes[:updated_at] }.max
        end

        protected

        def default_load_asynchronous?
          true
        end
      end

      def initialize(*)
        @original_key = nil
        @raw_value = nil
        @created_at = nil
        @updated_at = nil
        @description = nil
        @value_type = nil
        @deleted = false
        @persisted = false
        super
      end

      def history(limit: nil, offset: 0)
        items = self.class.history(key)
        items[offset, limit || items.length].collect do |attributes|
          HistoryItem.new(attributes)
        end
      end

      def create_history(changed_by:, created_at:, value: nil, deleted: false)
        item = {key: key, value: value, deleted: deleted, changed_by: changed_by, created_at: created_at}
        self.class.history(key).unshift(item)
      end

      def save!
        self.updated_at ||= Time.now
        self.created_at ||= updated_at
        if defined?(@original_key) && @original_key
          self.class.settings.delete(@original_key)
        end
        self.class.settings[key] = attributes
        set_persisted!
        true
      end

      def key=(value)
        @original_key ||= key
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

      def deleted=(value)
        @deleted = Coerce.boolean(value)
      end

      def created_at=(value)
        @created_at = SuperSettings::Coerce.time(value)
      end

      def updated_at=(value)
        @updated_at = SuperSettings::Coerce.time(value)
      end

      def deleted?
        !!@deleted
      end

      def persisted?
        !!@persisted
      end

      private

      def set_persisted!
        @persisted = true
      end

      def attributes
        {
          key: key,
          raw_value: raw_value,
          value_type: value_type,
          description: description,
          deleted: deleted?,
          updated_at: updated_at,
          created_at: created_at
        }
      end
    end
    # :nocov:
  end
end
