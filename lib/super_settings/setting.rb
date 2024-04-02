# frozen_string_literal: true

module SuperSettings
  # This is the model for interacting with settings. This class provides methods for finding, validating, and
  # updating settings.
  #
  # This class does not deal with actually persisting settings to and fetching them from a data store.
  # You need to specify the storage engine you want to use with the +storage+ class method. This gem
  # ships with storage engines for ActiveRecord, Redis, and HTTP (microservice). See the SuperSettings::Storage
  # class for more details.
  class Setting
    LAST_UPDATED_CACHE_KEY = "SuperSettings.last_updated_at"

    STRING = "string"
    INTEGER = "integer"
    FLOAT = "float"
    BOOLEAN = "boolean"
    DATETIME = "datetime"
    ARRAY = "array"

    VALUE_TYPES = [STRING, INTEGER, FLOAT, BOOLEAN, DATETIME, ARRAY].freeze

    ARRAY_DELIMITER = /[\n\r]+/.freeze

    # Exception raised if you try to save with invalid data.
    class InvalidRecordError < StandardError
    end

    include Attributes

    # The changed_by attribute is used to temporarily store an identifier for the user
    # who made a change to a setting to be stored in the history table. This value is optional
    # and is cleared after the record is saved.
    attr_accessor :changed_by

    # The namespace that the setting is saved under.
    attr_reader :namespace

    @after_save_blocks = []

    class << self
      attr_reader :after_save_blocks

      # Add a block of code that will be called when a setting is saved. The block will be
      # called with a Setting object. The object will have been saved, but the `changes`
      # hash will still be set indicating what was changed. You can define multiple after_save blocks.
      #
      # @yieldparam setting [SuperSetting::Setting]
      def after_save(&block)
        after_save_blocks << block
      end

      # Create a new setting with the specified attributes.
      #
      # @param attributes [Hash] hash of attribute names and values
      # @return [Setting]
      def create!(attributes)
        setting = new(attributes)
        storage.with_connection do
          setting.save!
        end
        setting
      end

      # Determine the value type from a value.
      #
      # @return [String]
      def value_type(value)
        case value
        when Integer
          INTEGER
        when Numeric
          FLOAT
        when TrueClass, FalseClass
          BOOLEAN
        when Time, Date
          DATETIME
        when Array
          ARRAY
        else
          STRING
        end
      end

      # Get the storage class to use for persisting data.
      #
      # @return [SuperSettings::Storage]
      # @api private
      def storage
        SuperSettings.storage
      end

      # Deprecated method for setting the storage class.
      #
      # @deprecated use SuperSetting.storage instead.
      def storage=(val)
        SuperSettings.storage = val
      end

      # Get the cache to use for caching values.
      #
      # @return [Object]
      # @api private
      def cache
        SuperSettings.cache
      end

      # Deprecated method for setting the cache.
      #
      # @deprecated use SuperSetting.cache instead.
      def cache=(val)
        SuperSettings.cache = val
      end
    end

    # @param attributes [Hash]
    def initialize(attributes = {})
      @changes = {}
      @errors = {}
      if attributes.is_a?(Storage)
        @record = attributes
      else
        @record = self.class.storage.new
        self.attributes = attributes
        self.value_type ||= STRING
      end
    end

    def namespace
      @record.namespace
    end

    def namespace=(val)
      val = val&.to_s
      will_change!(:namespace, val) unless namespace == val
      @record.namespace = val
    end

    # Get the unique key for the setting.
    #
    # @return [String]
    def key
      @record.key
    end

    # Set the value of the setting. The value will be coerced to a string for storage.
    #
    # @param val [Object]
    def key=(val)
      val = val&.to_s
      will_change!(:key, val) unless key == val
      @record.key = val
    end

    # The value of a setting coerced to the appropriate class depending on its value type.
    #
    # @return [Object]
    def value
      if deleted?
        nil
      else
        coerce(raw_value)
      end
    end

    # Set the value of the setting.
    #
    # @param val [Object]
    def value=(val)
      val = serialize(val) unless val.is_a?(Array)
      val = val.join("\n") if val.is_a?(Array)
      self.raw_value = val
    end

    # Get the type of value being stored in the setting.
    #
    # @return [String] one of string, integer, float, boolean, datetime, or array.
    def value_type
      @record.value_type
    end

    # Set the value type of the setting.
    #
    # @param val [String] one of string, integer, float, boolean, datetime, or array.
    def value_type=(val)
      val = val&.to_s
      will_change!(:value_type, val) unless value_type == val
      @record.value_type = val
    end

    # Get the description for the setting.
    #
    # @return [String]
    def description
      @record.description
    end

    # Set the description of the setting.
    #
    # @param val [String]
    def description=(val)
      val = val&.to_s
      val = nil if val&.empty?
      will_change!(:description, val) unless description == val
      @record.description = val
    end

    # Return true if the setting has been marked as deleted.
    #
    # @return [Boolean]
    def deleted?
      @record.deleted?
    end

    alias_method :deleted, :deleted?

    # Set the deleted flag on the setting. Deleted settings are not visible but are not actually
    # removed from the data store.
    #
    # @param val [Boolean]
    def deleted=(val)
      val = Coerce.boolean(val)
      will_change!(:deleted, val) unless deleted? == val
      @record.deleted = val
    end

    # Get the time the setting was first created.
    #
    # @return [Time]
    def created_at
      @record.created_at
    end

    # Set the time when the setting was created.
    #
    # @param val [Time, DateTime]
    def created_at=(val)
      val = Coerce.time(val)
      will_change!(:created_at, val) unless created_at == val
      @record.created_at = val
    end

    # Get the time the setting was last updated.
    #
    # @return [Time]
    def updated_at
      @record.updated_at
    end

    # Set the time when the setting was last updated.
    #
    # @param val [Time, DateTime]
    def updated_at=(val)
      val = Coerce.time(val)
      will_change!(:updated_at, val) unless updated_at == val
      @record.updated_at = val
    end

    # Return true if the setting has a string value type.
    #
    # @return [Boolean]
    def string?
      value_type == STRING
    end

    # Return true if the setting has an integer value type.
    #
    # @return [Boolean]
    def integer?
      value_type == INTEGER
    end

    # Return true if the setting has a float value type.
    # @return [Boolean]
    def float?
      value_type == FLOAT
    end

    # Return true if the setting has a boolean value type.
    # @return [Boolean]
    def boolean?
      value_type == BOOLEAN
    end

    # Return true if the setting has a datetime value type.
    # @return [Boolean]
    def datetime?
      value_type == DATETIME
    end

    # Return true if the setting has an array value type.
    # @return [Boolean]
    def array?
      value_type == ARRAY
    end

    # Save the setting to the data storage engine.
    #
    # @return [void]
    def save!
      record_value_change

      unless valid?
        raise InvalidRecordError.new(errors.values.join("; "))
      end

      timestamp = Time.now
      self.created_at ||= timestamp
      self.updated_at = timestamp unless updated_at && changed?(:updated_at)

      self.class.storage.with_connection do
        self.class.storage.transaction do
          @record.save!
        end

        begin
          NamespacedSettings.new(namespace).clear_last_updated_cache
          call_after_save_callbacks
        ensure
          clear_changes
        end
      end
      nil
    end

    # Return true if the record has been stored in the data storage engine.
    #
    # @return [Boolean]
    def persisted?
      @record.persisted?
    end

    # Return true if the record has valid data.
    #
    # @return [Boolean]
    def valid?
      validate!
      @errors.empty?
    end

    # Return hash of errors generated from the last call to +valid?+
    #
    # @return [Hash<String, Array<String>>]
    attr_reader :errors

    # Mark the record as deleted. The record will not actually be deleted since it's still needed
    # for caching purposes, but it will no longer be returned by queries.
    #
    # @return [void]
    def delete!
      update!(deleted: true)
    end

    # Update the setting attributes and save it.
    #
    # @param attributes [Hash]
    # @return [void]
    def update!(attributes)
      self.attributes = attributes
      save!
    end

    # Return array of history items reflecting changes made to the setting over time. Items
    # should be returned in reverse chronological order so that the most recent changes are first.
    #
    # @return [Array<SuperSettings::History>]
    def history(limit: nil, offset: 0)
      @record.history(limit: limit, offset: offset)
    end

    # Serialize to a hash that is used for rendering JSON responses.
    #
    # @return [Hash]
    def as_json(options = nil)
      attributes = {
        key: key,
        value: value,
        value_type: value_type,
        description: description,
        created_at: created_at,
        updated_at: updated_at
      }
      attributes[:deleted] = true if deleted?
      attributes
    end

    # Serialize to a JSON string.
    #
    # @return [String]
    def to_json(options = nil)
      as_json.to_json(options)
    end

    # Get hash of attribute changes. The hash keys are the names of attributes that
    # have changed and the values are an array with [old value, new value]. The keys
    # will be one of key, raw_value, value_type, description, deleted, created_at, or updated_at.
    #
    # @return [Hash<String, Array>]
    def changes
      @changes.dup
    end

    private

    # Coerce a value for the appropriate value type.
    def coerce(value)
      return nil if value.respond_to?(:empty?) ? value.empty? : value.to_s.empty?

      case value_type
      when Setting::STRING
        value.freeze
      when Setting::INTEGER
        Integer(value)
      when Setting::FLOAT
        Float(value)
      when Setting::BOOLEAN
        Coerce.boolean(value)
      when Setting::DATETIME
        Coerce.time(value).freeze
      when Setting::ARRAY
        if value.is_a?(String)
          value.split(Setting::ARRAY_DELIMITER).map(&:freeze).freeze
        else
          Array(value).reject { |v| v.respond_to?(:empty?) ? v.empty? : v.to_s.empty? }.collect { |v| v.to_s.freeze }.freeze
        end
      else
        value.freeze
      end
    rescue ArgumentError
      nil
    end

    # Format the value so it can be saved as a string in the database.
    def serialize(value)
      if value.nil? || value.to_s.empty?
        nil
      elsif value.is_a?(Time) || value.is_a?(DateTime)
        value.utc.iso8601(6)
      else
        coerce(value.to_s)
      end
    end

    # Update the histories association whenever the value or key is changed.
    def record_value_change
      return unless changed?(:raw_value) || changed?(:deleted) || changed?(:key)
      recorded_value = (deleted? ? nil : raw_value)
      @record.create_history(value: recorded_value, deleted: deleted?, changed_by: changed_by, created_at: Time.now)
    end

    def clear_changes
      @changes = {}
      self.changed_by = nil
    end

    def will_change!(attribute, value)
      attribute = attribute.to_s
      change = @changes[attribute]
      unless change
        change = [send(attribute)]
        @changes[attribute] = change
      end
      change[1] = value # rubocop:disable Lint/UselessSetterCall
    end

    def changed?(attribute)
      @changes.include?(attribute.to_s)
    end

    def raw_value=(val)
      val = val&.to_s
      val = nil if val&.empty?
      will_change!(:raw_value, val) unless raw_value == val
      @raw_value = val
      @record.raw_value = val
    end

    def raw_value
      @record.raw_value
    end

    def validate!
      if key.to_s.empty?
        add_error(:key, "cannot be empty")
      elsif key.to_s.size > 190
        add_error(:key, "must be less than 190 characters")
      end

      add_error(:value_type, "must be one of #{Setting::VALUE_TYPES.join(", ")}") unless Setting::VALUE_TYPES.include?(value_type)

      add_error(:value, "must be less than 4096 characters") if raw_value.to_s.size > 4096

      if !raw_value.nil? && coerce(raw_value).nil?
        if value_type == Setting::INTEGER
          add_error(:value, "must be an integer")
        elsif value_type == Setting::FLOAT
          add_error(:value, "must be a number")
        elsif value_type == Setting::DATETIME
          add_error(:value, "is not a valid datetime")
        end
      end
    end

    def add_error(attribute, message)
      attribute = attribute.to_s
      attribute_errors = @errors[attribute]
      unless attribute_errors
        attribute_errors = []
        @errors[attribute] = attribute_errors
      end
      attribute_errors << "#{attribute.tr("_", " ")} #{message}"
    end

    def call_after_save_callbacks
      self.class.after_save_blocks.each do |block|
        block.call(self)
      end
    end
  end
end
