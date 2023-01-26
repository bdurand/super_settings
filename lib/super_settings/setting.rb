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

    class << self
      # Set a cache to use for caching values. This feature is optional. The cache must respond
      # to +delete(key)+ and +fetch(key, &block)+. If you are running in a Rails environment,
      # you can use +Rails.cache+ or any ActiveSupport::Cache::Store object.
      attr_accessor :cache

      # Set the storage class to use for persisting data.
      attr_writer :storage

      # @return [Class] The storage class to use for persisting data.
      # @api private
      def storage
        if defined?(@storage)
          @storage
        elsif defined?(::SuperSettings::Storage::ActiveRecordStorage)
          ::SuperSettings::Storage::ActiveRecordStorage
        else
          raise ArgumentError.new("No storage class defined for #{name}")
        end
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

      # Get all the settings. This will even return settings that have been marked as deleted.
      # If you just want current settings, then call #active instead.
      #
      # @return [Array<Setting>]
      def all
        storage.with_connection do
          storage.all.collect { |record| new(record) }
        end
      end

      # Get all the current settings.
      #
      # @return [Array<Setting>]
      def active
        storage.with_connection do
          storage.active.collect { |record| new(record) }
        end
      end

      # Get all settings that have been updated since the specified time stamp.
      #
      # @param time [Time]
      # @return [Array<Setting>]
      def updated_since(time)
        storage.with_connection do
          storage.updated_since(time).collect { |record| new(record) }
        end
      end

      # Get a setting by its unique key.
      #
      # @return Setting
      def find_by_key(key)
        record = storage.with_connection { storage.find_by_key(key) }
        if record
          new(record)
        end
      end

      # Return the maximum updated at value from all the rows. This is used in the caching
      # scheme to determine if data needs to be reloaded from the database.
      #
      # @return [Time]
      def last_updated_at
        fetch_from_cache(LAST_UPDATED_CACHE_KEY) do
          storage.with_connection { storage.last_updated_at }
        end
      end

      # Bulk update settings in a single database transaction. No changes will be saved
      # if there are any invalid records.
      #
      # @example
      #
      #   SuperSettings.bulk_update([
      #     {
      #       key: "setting-key",
      #       value: "foobar",
      #       value_type: "string",
      #       description: "A sample setting"
      #     },
      #     {
      #       key: "setting-to-delete",
      #       deleted: true
      #     }
      #   ])
      #
      # @param params [Array] Array of hashes with setting attributes. Each hash must include
      #   a "key" element to identify the setting. To update a key, it must also include at least
      #   one of "value", "value_type", or "description". If one of these attributes is present in
      #   the hash, it will be updated. If a setting with the given key does not exist, it will be created.
      #   A setting may also be deleted by providing the attribute "deleted: true".
      # @return [Array] Boolean indicating if update succeeded, Array of settings affected by the update;
      #   if the settings were not updated, the +errors+ on the settings that failed validation will be filled.
      def bulk_update(params, changed_by = nil)
        all_valid, settings = update_settings(params, changed_by)
        if all_valid
          storage.with_connection do
            storage.transaction do
              settings.each do |setting|
                setting.save!
              end
            end
          end
          clear_last_updated_cache
        end
        [all_valid, settings]
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

      # Clear the last updated timestamp from the cache.
      #
      # @api private
      def clear_last_updated_cache
        cache&.delete(Setting::LAST_UPDATED_CACHE_KEY)
      end

      private

      # Updates settings in memory from an array of parameters.
      #
      # @param params [Array<Hash>] Each hash must contain a "key" element and may contain elements
      #     for "value", "value_type", "description", and "deleted".
      # @param changed_by [String] Value to be stored in the history for each setting
      # @return [Array] The first value is a boolean indicating if all the settings are valid,
      #     the second is an array of settings with their attributes updated in memory and ready to be saved.
      def update_settings(params, changed_by)
        changed = {}
        all_valid = true

        params.each do |setting_params|
          setting_params = stringify_keys(setting_params)
          next if Coerce.blank?(setting_params["key"])
          next if ["value_type", "value", "description", "deleted"].all? { |name| Coerce.blank?(setting_params[name]) }

          key = setting_params["key"]
          setting = changed[key] || Setting.find_by_key(key)
          unless setting
            next if Coerce.present?(setting_params["delete"])
            setting = Setting.new(key: setting_params["key"])
          end

          if Coerce.boolean(setting_params["deleted"])
            setting.deleted = true
            setting.changed_by = changed_by
          else
            setting.value_type = setting_params["value_type"] if setting_params.include?("value_type")
            setting.value = setting_params["value"] if setting_params.include?("value")
            setting.description = setting_params["description"] if setting_params.include?("description")
            setting.deleted = false if setting.deleted?
            setting.changed_by = changed_by
            all_valid &= setting.valid?
          end
          changed[setting.key] = setting
        end

        [all_valid, changed.values]
      end

      def fetch_from_cache(key, &block)
        if cache
          cache.fetch(key, expires_in: 60, &block)
        else
          block.call
        end
      end

      def stringify_keys(hash)
        transformed = {}
        hash.each do |key, value|
          transformed[key.to_s] = value
        end
        transformed
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
          self.class.clear_last_updated_cache
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
  end
end
