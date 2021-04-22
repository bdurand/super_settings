# frozen_string_literal: true

require_relative "application_record"

module SuperSettings
  class Setting < ApplicationRecord

    LAST_UPDATED_CACHE_KEY = "SuperSettings.last_updated_at"

    STRING = "string"
    INTEGER = "integer"
    FLOAT = "float"
    BOOLEAN = "boolean"
    DATETIME = "datetime"
    ARRAY = "array"

    VALUE_TYPES = [STRING, INTEGER, FLOAT, BOOLEAN, DATETIME, ARRAY].freeze

    ARRAY_DELIMITER = /[\n\r]+/.freeze

    self.table_name = "super_settings"

    attr_accessor :changed_by

    default_scope -> { where(deleted: false) }

    scope :with_deleted, -> { unscope(where: :deleted) }

    # Scope to select just the date needed to load the setting values.
    scope :value_data, -> { select([:id, :key, :value_type, :raw_value, :deleted]) }

    has_many :histories, class_name: "SuperSettings::History", foreign_key: :key, primary_key: :key

    validates :value_type, inclusion: {in: VALUE_TYPES}
    validates :key, presence: true, length: {maximum: 255}, uniqueness: true
    validates :raw_value, length: {maximum: 4096}
    validate { validate_parsable_value(raw_value) }

    after_find :clear_changed_by
    after_save :clear_changed_by

    before_save do
      self.raw_value = serialize(raw_value) unless array?
      record_value_change
    end

    after_commit do
      if self.class.cache
        self.class.cache.delete(LAST_UPDATED_CACHE_KEY)
        self.class.remove_from_cache(key)
          if respond_to?(:saved_change_to_key) && saved_change_to_key? && respond_to?(:key_before_last_save)
          self.class.remove_from_cache(key_before_last_save)
        end
      end
    end

    class << self
      def last_updated_at
        fetch_from_cache(LAST_UPDATED_CACHE_KEY) do
          with_deleted.maximum(:updated_at)
        end
      end

      def fetch(key)
        fetch_from_cache(cache_key(key)) do
          value_data.find_by(key: key)&.value
        end
      end

      def cache=(cache_store)
        @cache = cache_store
      end

      def cache
        @cache if defined?(@cache)
      end

      def remove_from_cache(key)
        cache.delete(cache_key(key)) if cache
      end

      private

      def cache_key(key)
        "SuperSettings[#{key}]"
      end

      def fetch_from_cache(key, &block)
        if cache
          cache.fetch(key, &block)
        else
          block.call
        end
      end
    end

    def value
      if deleted?
        nil
      else
        coerce(raw_value)
      end
    end

    def value=(v)
      self.raw_value = (v.is_a?(Array) ? v.join("\n") : v)
    end

    def string?
      value_type == STRING
    end

    def integer?
      value_type == INTEGER
    end

    def float?
      value_type == FLOAT
    end

    def boolean?
      value_type == BOOLEAN
    end

    def datetime?
      value_type == DATETIME
    end

    def array?
      value_type == ARRAY
    end

    def destroy!
      update!(deleted: true)
    end
    
    def as_json(options = nil)
      {
        id: id,
        key: key,
        value: value,
        value_type: value_type,
        description: description,
        created_at: created_at,
        updated_at: updated_at
      }
    end

    private

    def coerce(value)
      return nil if value.blank?

      case value_type
      when STRING
        value.freeze
      when INTEGER
        Integer(value)
      when FLOAT
        Float(value)
      when BOOLEAN
        BOOLEAN_PARSER.cast(value)
      when DATETIME
        Time.parse(value).in_time_zone(Time.zone).freeze
      when ARRAY
        if value.is_a?(String)
          value.split(ARRAY_DELIMITER).map(&:freeze).freeze
        else
          Array(value).reject(&:blank?).map { |v| v.to_s.freeze }.freeze
        end
      else
        value.freeze
      end
    rescue ArgumentError
      nil
    end

    def serialize(value)
      if value.blank?
        nil
      elsif value.is_a?(Time) || value.is_a?(DateTime)
        value.utc.iso8601(6)
      else
        coerce(value.to_s)
      end
    end

    def validate_parsable_value(value)
      if value.present? && coerce(value).nil?
        if integer?
          errors.add(:value, :not_an_integer)
        elsif float?
          errors.add(:value, :not_a_number)
        elsif datetime?
          errors.add(:value, :invalid)
        end
      end
    end

    def record_value_change
      return unless raw_value_changed? || deleted_changed? || key_changed?
      history_attributes = {value: (deleted? ? nil : raw_value), deleted: deleted, changed_by: changed_by}
      if new_record?
        histories.build(history_attributes)
      else
        histories.create!(history_attributes)
      end
    end

    def clear_changed_by
      self.changed_by = nil
    end

  end
end
