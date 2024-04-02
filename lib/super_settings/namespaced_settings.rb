# frozen_string_literal: true

module SuperSettings
  # This class in the interface for interacting with namespaced settings. It provides
  # methods for finding and creating settings in a namespace.
  class NamespacedSettings
    attr_reader :namespace

    def initialize(namespace = nil)
      @namespace = namespace&.to_s
    end

    # Create a new setting with the specified attributes.
    #
    # @param attributes [Hash] hash of attribute names and values
    # @return [Setting]
    def create!(attributes)
      attributes = (attributes ? attributes.merge(namespace: namespace) : {namespace: namespace})
      Setting.create!(attributes)
    end

    # Get all the settings. This will even return settings that have been marked as deleted.
    # If you just want current settings, then call #active instead.
    #
    # @return [Array<Setting>]
    def all
      storage.with_connection do
        storage.all(namespace: namespace).collect do |record|
          Setting.new(record).tap { |setting| setting.namespace = namespace }
        end
      end
    end

    # Get all the current settings.
    #
    # @return [Array<Setting>]
    def active
      storage.with_connection do
        storage.active(namespace: namespace).collect do |record|
          Setting.new(record).tap { |setting| setting.namespace = namespace }
        end
      end
    end

    # Get all settings that have been updated since the specified time stamp.
    #
    # @param time [Time]
    # @return [Array<Setting>]
    def updated_since(time)
      storage.with_connection do
        storage.updated_since(time, namespace: namespace).collect do |record|
          Setting.new(record).tap { |setting| setting.namespace = namespace }
        end
      end
    end

    # Get a setting by its unique key.
    #
    # @return Setting
    def find_by_key(key)
      record = storage.with_connection { storage.find_by_key(key, namespace: namespace) }
      if record
        Setting.new(record).tap { |setting| setting.namespace = namespace }
      end
    end

    # Return the maximum updated at value from all the rows. This is used in the caching
    # scheme to determine if data needs to be reloaded from the database.
    #
    # @return [Time]
    def last_updated_at
      fetch_from_cache(last_updated_cache_key) do
        storage.with_connection { storage.last_updated_at(namespace: namespace) }
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

    # Clear the last updated timestamp from the cache.
    #
    # @api private
    def clear_last_updated_cache
      SuperSettings.cache&.delete(last_updated_cache_key)
    end

    private

    def storage
      SuperSettings.storage
    end

    def last_updated_cache_key
      if namespace.nil?
        Setting::LAST_UPDATED_CACHE_KEY
      else
        "#{namespace}:#{Setting::LAST_UPDATED_CACHE_KEY}"
      end
    end

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
        setting = changed[key] || find_by_key(key)
        unless setting
          next if Coerce.present?(setting_params["delete"])
          setting = Setting.new(key: setting_params["key"], namespace: namespace)
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
      if SuperSettings.cache
        SuperSettings.cache.fetch(key, expires_in: 60, &block)
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
end
