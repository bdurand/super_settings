# frozen_string_literal: true

# These classes are required for the gem to function.
require_relative "super_settings/attributes"
require_relative "super_settings/coerce"
require_relative "super_settings/configuration"
require_relative "super_settings/context"
require_relative "super_settings/instance"
require_relative "super_settings/local_cache"
require_relative "super_settings/namespaced_settings"
require_relative "super_settings/setting"
require_relative "super_settings/storage"

# This is the main interface to the access settings.
module SuperSettings
  # These classes are autoloaded when they are needed.
  autoload :Application, "super_settings/application"
  autoload :RestAPI, "super_settings/rest_api"
  autoload :RackApplication, "super_settings/rack_application"
  autoload :ControllerActions, "super_settings/controller_actions"
  autoload :HistoryItem, "super_settings/history_item"
  autoload :VERSION, "super_settings/version"

  DEFAULT_REFRESH_INTERVAL = 5.0

  NOT_SET = Object.new.freeze
  private_constant :NOT_SET

  @default_instance = Instance.new(namespace: nil, refresh_interval: DEFAULT_REFRESH_INTERVAL)
  @instance_map = {nil => @default_instance}

  class << self
    # Add a namespace to the settings. Namespaces allow you to group settings together. Each namespace
    # has its own set of keys and values.
    #
    # @param namespace [String, Symbol] the namespace to add. It can only contain letters, numbers,
    #   and underscores.
    # @return [SuperSettings::Instance]
    def add_namespace(namespace)
      unless namespace.to_s.match?(/\A[a-zA-Z0-9_]+\z/)
        raise ArgumentError.new("Namespace can only contain letters, numbers, and unscores")
      end

      @instance_map[namespace] ||= Instance.new(namespace: namespace, refresh_interval: Configuration.instance.refresh_interval)
    end

    # Get a namespaced instance of settings.
    #
    # @param namespace [String, Symbol] the namespace to get
    # @return [SuperSettings::Instance]
    def for(namespace = nil)
      instance = @instance_map[namespace&.to_s]
      unless instance
        raise ArgumentError.new("Namespace #{namespace.inspect} does not exist")
      end
      instance
    end

    # Get the storage class to use for persisting data.
    #
    # @return [Class] The storage class to use for persisting data.
    def storage
      if @storage == NOT_SET
        if defined?(::SuperSettings::Storage::ActiveRecordStorage)
          ::SuperSettings::Storage::ActiveRecordStorage
        else
          raise ArgumentError.new("No storage class defined for #{name}")
        end
      else
        @storage
      end
    end

    # Set the storage class to use for persisting data.
    attr_writer :storage

    # Set a cache to use for caching values. This feature is optional. The cache must respond
    # to +delete(key)+ and +fetch(key, &block)+. If you are running in a Rails environment,
    # you can use +Rails.cache+ or any ActiveSupport::Cache::Store object.
    attr_accessor :cache

    # Get a setting value cast to a string in the default namespace.
    #
    # @param key [String, Symbol]
    # @param default [String] value to return if the setting value is nil
    # @return [String]
    def get(key, default = nil)
      @default_instance.get(key, default)
    end

    # Alias for {#get} to allow using the [] operator to get a setting value.
    #
    # @param key [String, Symbol]
    # @return [String]
    def [](key)
      @default_instance.get(key)
    end

    # Get a setting value cast to an integer in the default namespace.
    #
    # @param key [String, Symbol]
    # @param default [Integer] value to return if the setting value is nil
    # @return [Integer]
    def integer(key, default = nil)
      @default_instance.integer(key, default)
    end

    # Get a setting value cast to a float in the default namespace.
    #
    # @param key [String, Symbol]
    # @param default [Numeric] value to return if the setting value is nil
    # @return [Float]
    def float(key, default = nil)
      @default_instance.float(key, default)
    end

    # Get a setting value cast to a boolean in the default namespace.
    #
    # @param key [String, Symbol]
    # @param default [Boolean] value to return if the setting value is nil
    # @return [Boolean]
    def enabled?(key, default = false)
      @default_instance.enabled?(key, default)
    end

    # Return true if a setting cast as a boolean evaluates to false in the default namespace.
    #
    # @param key [String, Symbol]
    # @param default [Boolean] value to return if the setting value is nil
    # @return [Boolean]
    def disabled?(key, default = true)
      !enabled?(key, !default)
    end

    # Get a setting value cast to a Time in the default namespace.
    #
    # @param key [String, Symbol]
    # @param default [Time] value to return if the setting value is nil
    # @return [Time]
    def datetime(key, default = nil)
      @default_instance.datetime(key, default)
    end

    # Get a setting value cast to an array of strings in the default namespace.
    #
    # @param key [String, Symbol]
    # @param default [Array] value to return if the setting value is nil
    # @return [Array]
    def array(key, default = nil)
      @default_instance.array(key, default)
    end

    # Create settings and update the local cache with the values in the default namespace.
    #
    # @param key [String, Symbol] the key to set
    # @param value [Object] the value to set
    # @param value_type [String, Symbol] the value type to set; if the setting does not already exist,
    #   this will be inferred from the value.
    # @return [void]
    def set(key, value, value_type: nil, &block)
      @default_instance.set(key, value, value_type: value_type, &block)
    end

    # Get a pseudo random number. This method works the same as Kernel.rand. However, if you are
    # inside a context block, then the random number will be the same each time you call this method.
    # This is useful when you need to generate a random number for a setting that you want to remain
    # constant for the duration of the block.
    #
    # So, for instance, if you are generating a random number to determine if a feature is enabled,
    # you can use this method to ensure that the feature is either always enabled or always disabled
    # for the duration of the block.
    #
    # @param max [Integer, Float, Range] the maximum value or range to use for the random number
    # @return [Integer, Float] the random number. It will be an integer if max is an integer, otherwise
    #   it will be a float.
    def rand(max = nil)
      max ||= 1.0
      context = current_context
      if context
        context.rand(max)
      else
        Random.rand(max)
      end
    end

    # Define a block where settings will remain unchanged. This is useful to
    # prevent settings from changing while you are in the middle of a block of
    # code that depends on the settings.
    def context(&block)
      reset_context = Thread.current[:super_settings_context].nil?
      begin
        Thread.current[:super_settings_context] ||= Context::Current.new
        yield
      ensure
        Thread.current[:super_settings_context] = nil if reset_context
      end
    end

    # Load the settings for all instances into the in memory cache.
    #
    # @return [void]
    def load_settings
      instances.each(&:load_settings)
      nil
    end

    # Force refresh the settings in the in memory caches to be in sync with the database.
    #
    # @return [void]
    def refresh_settings
      instances.each(&:refresh_settings)
      nil
    end

    # Reset the in memory cache. The cache will be automatically reloaded the next time
    # you access a setting.
    #
    # @return [void]
    def clear_cache
      instances.each(&:clear_cache)
      nil
    end

    # Return true if the in memory cache has been loaded from the database.
    #
    # @return [Boolean]
    def loaded?
      instances.all?(&:loaded?)
    end

    # Configure various aspects of the gem. The block will be yielded to with a configuration
    # object. You should use this method to configure the gem from an Rails initializer since
    # it will handle ensuring all the appropriate frameworks are loaded first.
    #
    # @yieldparam config [SuperSettings::Configuration]
    # @return [void]
    def configure(&block)
      Configuration.instance.defer(&block)
      unless defined?(Rails::Engine)
        Configuration.instance.call
      end
    end

    # Set the number of seconds between checks to synchronize the in memory cache from the database.
    # This setting aids in performance since it throttles the number of times the database is queried
    # for changes. However, changes made to the settings in the database will take up to the number of
    # seconds in the refresh interval to be updated in the cache.
    #
    # @return [void]
    def refresh_interval=(value)
      instances.each do |instance|
        instance.refresh_interval = value
      end
    end

    # URL for authenticating access to the application. This would normally be some kind of
    # login page. Browsers will be redirected here if they are denied access to the web UI.
    attr_accessor :authentication_url

    # Javascript to inject into the settings application HTML page. This can be used, for example,
    # to set authorization credentials stored client side to access the settings API.
    attr_accessor :web_ui_javascript

    # Get the current request context.
    #
    # @return [SuperSettings::Context::Current]
    # @api private
    def current_context
      Thread.current[:super_settings_context]
    end

    private

    def instances
      @instance_map.values
    end
  end
end

if defined?(Rails::Engine)
  require_relative "super_settings/engine"
end
