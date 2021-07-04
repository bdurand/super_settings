# frozen_string_literal: true

module SuperSettings
  # Model for storing settings to the database.
  class Setting
    LAST_UPDATED_CACHE_KEY = "SuperSettings.last_updated_at"

    STRING = "string"
    INTEGER = "integer"
    FLOAT = "float"
    BOOLEAN = "boolean"
    DATETIME = "datetime"
    ARRAY = "array"
    SECRET = "secret"

    VALUE_TYPES = [STRING, INTEGER, FLOAT, BOOLEAN, DATETIME, ARRAY, SECRET].freeze

    ARRAY_DELIMITER = /[\n\r]+/.freeze

    include Attributes

    # The changed_by attribute is used to temporarily store an identifier for the user
    # who made a change to a setting to be stored in the history table. This value is optional
    # and is cleared after the record is saved.
    attr_accessor :changed_by

    class << self
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

      # Return true if the storage class is fully setup. This should return false if,
      # for example, the database table isn't yet created.
      # @private
      def ready?
        @storage.ready?
      end

      def create!(attributes)
        setting = new(attributes)
        setting.save!
        setting
      end

      def all_settings
        storage.all_settings.collect { |record| new(record) }
      end

      def updated_since(time)
        storage.updated_since(time).collect { |record| new(record) }
      end

      def active_settings
        storage.active_settings.collect { |record| new(record) }
      end

      def find_by_key(key)
        record = storage.find_by_key(key)
        if record
          new(record)
        end
      end

      # Return the maximum updated at value from all the rows. This is used in the caching
      # scheme to determine if data needs to be reloaded from the database.
      # @return [Time]
      def last_updated_at
        fetch_from_cache(LAST_UPDATED_CACHE_KEY) do
          storage.last_updated_at
        end
      end

      # Bulk update settings in a single database transaction. No changes will be saved
      # if there are any invalid records.
      #
      # Example:
      #
      # ```
      # SuperSettings.bulk_update([
      #   {
      #     key: "setting-key",
      #     value: "foobar",
      #     value_type: "string",
      #     description: "A sample setting"
      #   },
      #   {
      #     key: "setting-to-delete",
      #     delete: true
      #   }
      # ])
      # ```
      #
      # @param params [Array] Array of hashes with setting attributes. Each hash must include
      #   a "key" element to identify the setting. To update a key, it must also include at least
      #   one of "value", "value_type", or "description". If one of these attributes is present in
      #   the hash, it will be updated. If a setting with the given key does not exist, it will be created.
      #   A setting may also be deleted by providing the attribute "deleted: true".
      # @return [Array] Boolean indicating if update succeeded, Array of settings affected by the update;
      #   if the settings were not updated, the `errors` on the settings that failed validation will be filled.
      def bulk_update(params, changed_by = nil)
        all_valid, settings = update_settings(params, changed_by)
        if all_valid
          storage.with_transaction do
            settings.each do |setting|
              setting.save!
            end
          end
          clear_last_updated_cache
        end
        [all_valid, settings]
      end

      # Determine the value type from a value.
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

      def clear_last_updated_cache
        cache&.delete(Setting::LAST_UPDATED_CACHE_KEY)
      end

      private

      def update_settings(params, changed_by)
        changed = {}
        all_valid = true

        params.each do |setting_params|
          setting_params = stringify_keys(setting_params)
          next if Coerce.blank?(setting_params["key"])
          next if ["value_type", "value", "description", "delete"].all? { |name| Coerce.blank?(setting_params[name]) }

          setting = Setting.find_by_key(setting_params["key"])
          unless setting
            next if Coerce.present?(setting_params["delete"])
            setting = Setting.new(key: setting_params["key"])
          end

          if Coerce.boolean(setting_params["delete"])
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
          cache.fetch(key, &block)
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

    def key
      @record.key
    end

    def key=(val)
      val = val&.to_s
      will_change!(:key, val) unless key == val
      @record.key = val
    end

    # @return [Object] the value of a setting coerced to the appropriate class depending on its value type.
    def value
      if deleted?
        nil
      else
        coerce(raw_value)
      end
    end

    # Set the value of the setting.
    def value=(val)
      val = (val.is_a?(Array) ? val.join("\n") : serialize(val))
      self.raw_value = val
    end

    def value_type
      @record.value_type
    end

    # Set the value type of the setting.
    # @param val (String) one of string, integer, float, boolean, datetime, array, or secret.
    def value_type=(val)
      val = val&.to_s
      will_change!(:value_type, val) unless value_type == val
      @record.value_type = val
    end

    def description
      @record.description
    end

    def description=(val)
      val = val&.to_s
      val = nil if val&.empty?
      will_change!(:description, val) unless description == val
      @record.description = val
    end

    def deleted?
      @record.deleted?
    end

    alias_method :deleted, :deleted?

    # Set the deleted flag on the setting. Deleted settings are not visible but are not actually
    # removed from the data store.
    def deleted=(val)
      val = Coerce.boolean(val)
      will_change!(:deleted, val) unless deleted? == val
      @record.deleted = val
    end

    def created_at
      @record.created_at
    end

    def created_at=(val)
      val = Coerce.time(val)
      will_change!(:created_at, val) unless created_at == val
      @record.created_at = val
    end

    def updated_at
      @record.updated_at
    end

    def updated_at=(val)
      val = Coerce.time(val)
      will_change!(:updated_at, val) unless updated_at == val
      @record.updated_at = val
    end

    # @return [true] if the setting has a string value type.
    def string?
      value_type == STRING
    end

    # @return [true] if the setting has an integer value type.
    def integer?
      value_type == INTEGER
    end

    # @return [true] if the setting has a float value type.
    def float?
      value_type == FLOAT
    end

    # @return [true] if the setting has a boolean value type.
    def boolean?
      value_type == BOOLEAN
    end

    # @return [true] if the setting has a datetime value type.
    def datetime?
      value_type == DATETIME
    end

    # @return [true] if the setting has an array value type.
    def array?
      value_type == ARRAY
    end

    # @return [true] if the setting has a secret value type.
    def secret?
      value_type == SECRET
    end

    # @return [true] if the setting is a secret setting and the value is encrypted in the database.
    def encrypted?
      secret? && Encryption.encrypted?(raw_value)
    end

    # Save the setting to the data storage engine.
    def save!
      set_raw_value
      timestamp = Time.now
      self.created_at ||= timestamp
      self.updated_at = timestamp unless updated_at && changed?(:updated_at)

      self.class.storage.with_transaction do
        @record.store!
      end

      begin
        self.class.clear_last_updated_cache
        redact_history! if history_needs_redacting?
      ensure
        clear_changes
      end
    end

    # @return [Boolean] true if the record has been stored in the data storage engine.
    def persisted?
      @record.stored?
    end

    # @return [Boolean] true if the record has valid data.
    def valid?
      validate!
      @errors.empty?
    end

    # @return [Hash<String, Array<String>>] hash of errors generated from the last call to `valid?`
    attr_reader :errors

    # Mark the record as deleted. The record will not actually be deleted since it's still needed
    # for caching purposes, but it will no longer be returned by queries.
    def delete!
      update!(deleted: true)
    end

    def update!(attributes)
      self.attributes = attributes
      save!
    end

    # Return array of history items reflecting changes made to the setting over time. Items
    # should be returned in reverse chronological order so that the most recent changes are first.
    # @return [Array<SuperSettings::History>]
    def history(limit: nil, offset: 0)
      @record.history(limit: limit, offset: offset)
    end

    # Serialize to a hash that is used for rendering JSON responses.
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
      attributes[:encrypted] = encrypted? if secret?
      attributes[:deleted] = true if deleted?
      attributes
    end

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
      when Setting::SECRET
        begin
          Encryption.decrypt(value).freeze
        rescue Encryption::InvalidSecretError
          nil
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

    # Set the raw string value that will be persisted to the data store.
    def set_raw_value
      if value_type == Setting::SECRET && !raw_value.to_s.empty? && (changed?(:raw_value) || !Encryption.encrypted?(raw_value))
        self.raw_value = Encryption.encrypt(raw_value)
      end
      record_value_change
    end

    # Update the histories association whenever the value or key is changed.
    def record_value_change
      return unless changed?(:raw_value) || changed?(:deleted) || changed?(:key)
      recorded_value = (deleted? || value_type == Setting::SECRET ? nil : raw_value)
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

    def history_needs_redacting?
      value_type == Setting::SECRET && changed?(:value_type)
    end

    def redact_history!
      @record.send(:redact_history!)
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
