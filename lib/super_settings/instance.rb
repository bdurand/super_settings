# frozen_string_literal: true

module SuperSettings
  class Instance
    attr_reader :namespace

    def initialize(namespace:, refresh_interval:)
      @namespace = namespace
      @local_cache = LocalCache.new(namespace: namespace, refresh_interval: refresh_interval)
    end

    # Get a setting value cast to a string.
    #
    # @param key [String, Symbol]
    # @param default [String] value to return if the setting value is nil
    # @return [String]
    def get(key, default = nil)
      val = context_setting(key)
      val.nil? ? default : val.to_s
    end

    # Alias for {#get} to allow using the [] operator to get a setting value.
    #
    # @param key [String, Symbol]
    # @return [String]
    def [](key)
      get(key)
    end

    # Get a setting value cast to an integer.
    #
    # @param key [String, Symbol]
    # @param default [Integer] value to return if the setting value is nil
    # @return [Integer]
    def integer(key, default = nil)
      val = context_setting(key)
      (val.nil? ? default : val)&.to_i
    end

    # Get a setting value cast to a float.
    #
    # @param key [String, Symbol]
    # @param default [Numeric] value to return if the setting value is nil
    # @return [Float]
    def float(key, default = nil)
      val = context_setting(key)
      (val.nil? ? default : val)&.to_f
    end

    # Get a setting value cast to a boolean.
    #
    # @param key [String, Symbol]
    # @param default [Boolean] value to return if the setting value is nil
    # @return [Boolean]
    def enabled?(key, default = false)
      val = context_setting(key)
      Coerce.boolean(val.nil? ? default : val)
    end

    # Return true if a setting cast as a boolean evaluates to false.
    #
    # @param key [String, Symbol]
    # @param default [Boolean] value to return if the setting value is nil
    # @return [Boolean]
    def disabled?(key, default = true)
      !enabled?(key, !default)
    end

    # Get a setting value cast to a Time.
    #
    # @param key [String, Symbol]
    # @param default [Time] value to return if the setting value is nil
    # @return [Time]
    def datetime(key, default = nil)
      val = context_setting(key)
      Coerce.time(val.nil? ? default : val)
    end

    # Get a setting value cast to an array of strings.
    #
    # @param key [String, Symbol]
    # @param default [Array] value to return if the setting value is nil
    # @return [Array]
    def array(key, default = nil)
      val = context_setting(key)
      val = default if val.nil?
      return nil if val.nil?
      Array(val).collect { |v| v&.to_s }
    end

    # Create settings and update the local cache with the values. If a block is given, then the
    # value will be reverted at the end of the block. This method can be used in tests when you
    # need to inject a specific value into your settings.
    #
    # @param key [String, Symbol] the key to set
    # @param value [Object] the value to set
    # @param value_type [String, Symbol] the value type to set; if the setting does not already exist,
    #   this will be inferred from the value.
    # @return [void]
    def set(key, value, value_type: nil)
      setting = NamespacedSettings.new(namespace).find_by_key(key)
      if setting
        setting.value_type = value_type if value_type
      else
        setting = Setting.new(key: key, namespace: namespace)
        setting.value_type = (value_type || Setting.value_type(value) || Setting::STRING)
      end
      previous_value = setting.value
      setting.value = value
      begin
        setting.save!
        local_cache.load_settings unless local_cache.loaded?
        local_cache.update_setting(setting)

        if block_given?
          yield
        end
      ensure
        if block_given?
          setting.value = previous_value
          setting.save!
          local_cache.load_settings unless local_cache.loaded?
          local_cache.update_setting(setting)
        end
      end
    end

    # Load the settings from the database into the in memory cache.
    #
    # @return [void]
    def load_settings
      local_cache.load_settings
      local_cache.wait_for_load
      nil
    end

    # Force refresh the settings in the in memory cache to be in sync with the database.
    #
    # @return [void]
    def refresh_settings
      local_cache.refresh
      nil
    end

    # Reset the in memory cache. The cache will be automatically reloaded the next time
    # you access a setting.
    #
    # @return [void]
    def clear_cache
      local_cache.reset
      nil
    end

    # Return true if the in memory cache has been loaded from the database.
    #
    # @return [Boolean]
    def loaded?
      local_cache.loaded?
    end

    # Set the number of seconds between checks to synchronize the in memory cache from the database.
    # This setting aids in performance since it throttles the number of times the database is queried
    # for changes. However, changes made to the settings in the databae will take up to the number of
    # seconds in the refresh interval to be updated in the cache.
    #
    # @return [void]
    def refresh_interval=(value)
      local_cache.refresh_interval = value
    end

    private

    attr_reader :local_cache

    def context_setting(key)
      key = key.to_s
      context = SuperSettings.current_context
      if context
        unless context.include?(key)
          context[key] = local_cache[key]
        end
        context[key]
      else
        local_cache[key]
      end
    end
  end
end
