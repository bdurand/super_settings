# frozen_string_literal: true

require "secret_keys"

require_relative "super_settings/boolean_parser"
require_relative "super_settings/configuration"
require_relative "super_settings/local_cache"
require_relative "super_settings/controller_actions"
require_relative "super_settings/version"

if defined?(Rails::Engine)
  require_relative "super_settings/engine"
  ActiveSupport.on_load(:active_record) do
    puts "LOADED<br>"
    require_relative "super_settings/setting"
    require_relative "super_settings/history"
  end
else
  require "active_record"
  require_relative "super_settings/setting"
  require_relative "super_settings/history"
end

# This is the main interface to the access settings.
module SuperSettings
  DEFAULT_REFRESH_INTERVAL = 5.0

  class << self
    # Get a setting value cast to a string.
    #
    # @param key [String, Symbol]
    # @param default [String] value to return if the setting value is nil
    # @return [String]
    def get(key, default: nil)
      val = local_cache[key]
      val.nil? ? default : val.to_s
    end

    # Get a setting value cast to an integer.
    #
    # @param key [String, Symbol]
    # @param default [Integer] value to return if the setting value is nil
    # @return [Integer]
    def integer(key, default: nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_i
    end

    # Get a setting value cast to a float.
    #
    # @param key [String, Symbol]
    # @param default [Numeric] value to return if the setting value is nil
    # @return [Float]
    def float(key, default: nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_f
    end

    # Get a setting value cast to a boolean.
    #
    # @param key [String, Symbol]
    # @param default [Boolean] value to return if the setting value is nil
    # @return [Boolean]
    def enabled?(key, default: false)
      val = local_cache[key]
      val.nil? ? BooleanParser.cast(default) : !!val
    end

    # Get a setting value cast to a Time.
    #
    # @param key [String, Symbol]
    # @param default [Time] value to return if the setting value is nil
    # @return [Time]
    def datetime(key, default: nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_time
    end

    # Get a setting value cast to an array of strings.
    #
    # @param key [String, Symbol]
    # @param default [Array] value to return if the setting value is nil
    # @return [Array]
    def array(key, default: nil)
      val = local_cache[key]
      Array(val.nil? ? default : val).map { |v| v&.to_s }
    end

    # Get setting values cast to a hash. This method can be used to cast the flat setting key/value
    # store into a structured data store. It uses a delimiter to define how keys are nested which
    # defaults to a dot.
    #
    # If, for example, you have three keys in you settings "A.B1.C1 = 1", "A.B1.C2 = 2", and "A.B2.C3 = 3", the
    # nested structure will be:
    #
    # `{"A" => {"B1" => {"C1" => 1, "C2" => 2}, "B2" => {"C3" => 3}}}`
    #
    # This whole hash would be returned if you called `hash` without any key. If you called it with the
    # key "A.B1", it would return `{"C1" => 1, "C2" => 2}`.
    #
    # @param key [String, Symbol] the prefix patter to fetch keys for; default to returning all settings
    # @param default [Hash] value to return if the setting value is nil
    # @param delimiter [String] the delimiter to use to define nested keys in the hash; defaults to "."
    # @return [Hash]
    def hash(key = nil, default: nil, delimiter: ".")
      flattened = local_cache.to_h
      root_key = ""
      if key.present?
        root_key = "#{key}#{delimiter}"
        reduced_hash = {}
        flattened.each do |k, v|
          if k.start_with?(root_key)
            reduced_hash[k[root_key.length, k.length]] = v
          end
        end
        flattened = reduced_hash
      end

      if flattened.empty?
        return default || {}
      end

      structured = {}
      flattened.each do |key, value|
        set_nested_hash_value(structured, key, value, delimiter)
      end
      structured
    end

    # Load the settings from the database into the in memory cache.
    def load_settings
      local_cache.load_settings
    end

    # Force refresh the settings in the in memory cache to be in sync with the database.
    def refresh_settings
      local_cache.refresh
    end

    # Reset the in memory cache. The cache will be automatically reloaded the next time
    # you access a setting.
    def clear_cache
      local_cache.reset
    end

    # Return true if the in memory cache has been loaded from the database.
    #
    # @return [Boolean]
    def loaded?
      local_cache.loaded?
    end

    # Configure various aspects of the gem. The block will be yielded to with a configuration
    # object. You should use this method to configure the gem from an Rails initializer since
    # it will handle ensuring all the appropriate frameworks are loaded first.
    #
    # yieldparam config [SuperSettings::Configuration]
    def configure(&block)
      Configuration.instance.defer(&block)
      unless defined?(Rails::Engine)
        Configuration.instance.call
      end
    end

    # Set the number of seconds between checks to synchronize the in memory cache from the database.
    # This setting aids in performance since it throttles the number of times the database is queried
    # for changes. However, changes made to the settings in the databae will take up to the number of
    # seconds in the refresh interval to be updated in the cache.
    def refresh_interval=(value)
      local_cache.refresh_interval = value
    end

    # Enable or disable the feature to track setting usage. This feature can be useful to track
    # if settings are actually being used. Since all settings are loaded into memory in the, you
    # don't want to let the number of settings to grow too large. The timestamp for a setting being
    # used is only updated at most once per hour since.
    #
    # Enabling the feature does require that the database connection used for loading the setting
    # also allow write access, so this is an opt in feature.
    #
    # @param value [Boolean]
    def track_last_used=(value)
      local_cache.track_last_used = value
    end

    # Return true if the feature to track setting usage is enabled.
    #
    # @return [Boolean]
    def track_last_used?
      local_cache.track_last_used?
    end

    # Set the secret used to encrypt secret settings in the database.
    #
    # If you need to roll your secret, you can pass in an array of values. The first one
    # specified will be used to encrypt values, but all of the keys will be tried when
    # decrypting a value already stored in the database.
    #
    # @param value [String, Array]
    def secret=(value)
      Setting.secret = value
      load_settings if loaded?
    end

    private

    def local_cache
      @local_cache ||= LocalCache.new(refresh_interval: DEFAULT_REFRESH_INTERVAL)
    end

    def set_nested_hash_value(hash, key, value, delimiter)
      key, sub_key = key.split(delimiter, 2)
      if sub_key
        sub_hash = hash[key]
        unless sub_hash.is_a?(Hash)
          sub_hash = {}
          hash[key] = sub_hash
        end
        set_nested_hash_value(sub_hash, sub_key, value, delimiter)
      else
        hash[key] = value
      end
    end
  end
end
