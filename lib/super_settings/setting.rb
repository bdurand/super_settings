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

    include ActiveModel::Model

    delegate :key, :value_type, :description, :deleted?, :updated_at, :created_at, to: :@record
    alias_method :deleted, :deleted?

    extend ActiveModel::Callbacks
    define_model_callbacks :save

    include ActiveModel::Dirty
    define_attribute_methods :key, :raw_value, :description, :value_type, :deleted, :updated_at, :created_at

    # The changed_by attribute is used to temporarily store an identifier for the user
    # who made a change to a setting to be stored in the history table. This value is optional
    # and is cleared after the record is saved.
    attr_accessor :changed_by

    validates :value_type, inclusion: {in: Setting::VALUE_TYPES}
    validates :key, presence: true, length: {maximum: 190}
    validates :raw_value, length: {maximum: 4096}
    validate { validate_parsable_value(raw_value) }

    after_save :clear_changed_by

    after_save :redact_history!, if: :history_needs_redacting?

    before_save :set_raw_value

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
          storage.transaction do
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
          setting_params = setting_params.with_indifferent_access if setting_params.is_a?(Hash)
          next if setting_params[:key].blank?
          next if [:value_type, :value, :description, :delete].all? { |name| setting_params[name].blank? }

          setting = Setting.find_by_key(setting_params[:key])
          unless setting
            next if setting_params[:delete].present?
            setting = Setting.new(key: setting_params[:key])
          end

          if BooleanParser.cast(setting_params[:delete])
            setting.deleted = true
            setting.changed_by = changed_by
          else
            setting.value_type = setting_params[:value_type] if setting_params.include?(:value_type)
            if setting_params.include?(:value)
              setting.value = (setting.boolean? ? setting_params[:value].present? : setting_params[:value])
            end
            setting.description = setting_params[:description] if setting_params.include?(:description)
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
    end

    def initialize(attributes = {})
      if attributes.is_a?(Storage)
        @record = attributes
      else
        @record = self.class.storage.new
        assign_attributes(attributes)
        self.value_type ||= STRING
      end
    end

    def key=(val)
      key_will_change! unless key == val
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
      self.raw_value = (val.is_a?(Array) ? val.join("\n") : val)
    end

    # Set the value type of the setting.
    # @param val (String) one of string, integer, float, boolean, datetime, array, or secret.
    def value_type=(val)
      value_type_will_change! unless value_type == val
      @record.value_type = val
    end

    def description=(val)
      description_will_change! unless description == val
      @record.description = val
    end

    # Set the deleted flag on the setting. Deleted settings are not visible but are not actually
    # removed from the data store.
    def deleted=(val)
      val = BooleanParser.cast(val)
      deleted_will_change! unless deleted? == val
      @record.deleted = val
    end

    def created_at=(val)
      val = val&.to_time
      created_at_will_change! unless created_at == val
      @record.created_at = val
    end

    def updated_at=(val)
      val = val&.to_time
      updated_at_will_change! unless updated_at == val
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
      timestamp = Time.now
      self.created_at ||= timestamp
      self.updated_at = timestamp unless updated_at && updated_at_changed?

      self.class.storage.transaction do
        run_callbacks(:save) do
          @record.store!
          changes_applied
        end
      end
      self.class.clear_last_updated_cache
      clear_changes_information
    end

    # @return [Boolean] true if the record has been stored in the data storage engine.
    def persisted?
      @record.stored?
    end

    # Mark the record as deleted. The record will not actually be deleted since it's still needed
    # for caching purposes, but it will no longer be returned by queries.
    def delete!
      update!(deleted: true)
    end

    def update!(attributes)
      assign_attributes(attributes)
      save!
    end

    def reload
      @record.reload
      clear_changed_by
      clear_changes_information
      self
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
      return nil if value.blank?

      case value_type
      when Setting::STRING
        value.freeze
      when Setting::INTEGER
        Integer(value)
      when Setting::FLOAT
        Float(value)
      when Setting::BOOLEAN
        BooleanParser.cast(value)
      when Setting::DATETIME
        Time.parse(value).in_time_zone(Time.zone).freeze
      when Setting::ARRAY
        if value.is_a?(String)
          value.split(Setting::ARRAY_DELIMITER).map(&:freeze).freeze
        else
          Array(value).reject(&:blank?).map { |v| v.to_s.freeze }.freeze
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
        if value_type == Setting::INTEGER
          errors.add(:value, :not_an_integer)
        elsif value_type == Setting::FLOAT
          errors.add(:value, :not_a_number)
        elsif value_type == Setting::DATETIME
          errors.add(:value, :invalid)
        end
      end
    end

    # Set the raw string value that will be persisted to the data store.
    def set_raw_value
      self.raw_value = serialize(raw_value) unless value_type == Setting::ARRAY
      if value_type == Setting::SECRET && raw_value.present? && (raw_value_changed? || !Encryption.encrypted?(raw_value))
        self.raw_value = Encryption.encrypt(raw_value)
      end
      record_value_change
    end

    # Update the histories association whenever the value or key is changed.
    def record_value_change
      return unless raw_value_changed? || deleted_changed? || key_changed?
      recorded_value = (deleted? || value_type == Setting::SECRET ? nil : raw_value)
      history_attributes = {value: recorded_value, deleted: deleted?, changed_by: changed_by, created_at: Time.now}
      @record.create_history(history_attributes)
    end

    # Clear the changed_by attribute.
    def clear_changed_by
      self.changed_by = nil
    end

    def history_needs_redacting?
      return false unless value_type == Setting::SECRET
      if defined?(value_type_previously_changed?)
        value_type_previously_changed?
      else
        value_type_changed?
      end
    end

    def redact_history!
      @record.send(:redact_history!)
    end

    def raw_value=(val)
      raw_value_will_change! unless raw_value == val
      @record.raw_value = val
    end

    def raw_value
      @record.raw_value
    end
  end
end
