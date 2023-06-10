# frozen_string_literal: true

module SuperSettings
  # Cache that stores the settings in memory so they can be looked up without any
  # network overhead. All of the settings will be loaded in the cache and the database
  # will only be checked every few seconds for changes so that lookups are very fast.
  #
  # The cache is thread safe and it ensures that only a single thread will ever be
  # trying to update the cache at a time to avoid any dog piling effects.
  class LocalCache
    # @private
    NOT_DEFINED = Object.new.freeze
    private_constant :NOT_DEFINED

    # @private
    DRIFT_FACTOR = 10
    private_constant :DRIFT_FACTOR

    # Number of seconds that the cache will be considered fresh. The database will only be
    # checked for changed settings at most this often.
    attr_reader :refresh_interval

    # @param refresh_interval [Numeric] number of seconds to wait between checking for setting updates
    def initialize(refresh_interval:)
      @refresh_interval = refresh_interval
      @lock = Mutex.new
      reset
    end

    # Get a setting value from the cache.
    #
    # This method will periodically check the cache for freshness and update the cache from
    # the database if there are any differences.
    #
    # Cache misses will be stored in the cache so that a request for a missing setting does not
    # hit the database every time. This does mean that that you should not call this method with
    # a large number of dynamically generated keys since that could lead to memory bloat.
    #
    # @param key [String, Symbol] setting key
    def [](key)
      ensure_cache_up_to_date!
      key = key.to_s
      value = @cache[key]

      if value.nil? && !@cache.include?(key)
        if @refreshing
          value = NOT_DEFINED
        else
          setting = Setting.find_by_key(key)
          value = (setting ? setting.value : NOT_DEFINED)
          # Guard against caching too many cache missees; at some point it's better to slam
          # the database rather than run out of memory.
          if setting || @cache.size < 100_000
            @lock.synchronize do
              # For case where one thread could be iterating over the cache while it's updated causing an error
              @cache = @cache.merge(key => value).freeze
            end
          end
        end
      end

      return nil if value == NOT_DEFINED
      value
    end

    # Check if the cache includes a key. Note that this will return true if you have tried
    # to fetch a non-existent key since the cache will store that as undefined. This method
    # is provided for testing purposes.
    #
    # @api private
    # @param key [String, Symbol] setting key
    # @return [Boolean]
    def include?(key)
      @cache.include?(key.to_s)
    end

    # Get the number of entries in the cache. Note that this will include cache misses as well.
    #
    # @api private
    # @return the number of entries in the cache.
    def size
      ensure_cache_up_to_date!
      @cache.size
    end

    # Return the cached settings as a key/value hash. Calling this method will load the cache
    # with the settings if they have not already been loaded.
    #
    # @return [Hash]
    def to_h
      ensure_cache_up_to_date!
      hash = {}
      @cache.each do |key, data|
        value, _ = data
        hash[key] = value unless value == NOT_DEFINED
      end
      hash
    end

    # Return true if the cache has already been loaded from the database.
    #
    # @return [Boolean]
    def loaded?
      !!@last_refreshed
    end

    # Load all the settings from the database into the cache.
    def load_settings(asynchronous = false)
      return if @refreshing

      @lock.synchronize do
        return if @refreshing
        @refreshing = true
        @next_check_at = Time.now + @refresh_interval
      end

      load_block = lambda do
        begin
          values = {}
          start_time = Time.now
          Setting.active.each do |setting|
            values[setting.key] = setting.value.freeze
          end
          set_cache_values(start_time) { values }
        ensure
          @refreshing = false
        end
      end

      if asynchronous
        Thread.new(&load_block)
      else
        load_block.call
      end
    end

    # Load only settings that have changed since the last load.
    def refresh(asynchronous = false)
      last_refresh_time = @last_refreshed
      return if last_refresh_time.nil?
      return if @refreshing

      @lock.synchronize do
        return if @refreshing
        @next_check_at = Time.now + @refresh_interval
        return if @cache.empty?
        @refreshing = true
      end

      refresh_block = lambda do
        begin
          last_db_update = Setting.last_updated_at
          if last_db_update.nil? || last_db_update >= last_refresh_time - 1
            merge_load(last_refresh_time)
          end
        ensure
          @refreshing = false
        end
      end

      if asynchronous
        Thread.new(&refresh_block)
      else
        refresh_block.call
      end
    end

    # Reset the cache to an unloaded state.
    def reset
      @lock.synchronize do
        @cache = {}.freeze
        @last_refreshed = nil
        @next_check_at = Time.now + @refresh_interval
        @refreshing = false
      end
    end

    # Set the number of seconds to wait between cache refresh checks.
    #
    # @param seconds [Numeric]
    def refresh_interval=(seconds)
      @lock.synchronize do
        @refresh_interval = seconds.to_f
        @next_check_at = Time.now + @refresh_interval if @next_check_at > Time.now + @refresh_interval
      end
    end

    # Update a single setting directly into the cache.
    # @api private
    def update_setting(setting)
      return if Coerce.blank?(setting.key)
      @lock.synchronize do
        @cache = @cache.merge(setting.key => setting.value)
      end
    end

    # Wait for the settings to be loaded if a new load was triggered. This can happen asynchronously.
    # @api private
    def wait_for_load
      loop do
        return unless @refreshing
        sleep(0.001)
      end
    end

    private

    # Load just the settings have that changed since the specified timestamp.
    def merge_load(last_refresh_time)
      changed_settings = {}
      start_time = Time.now
      Setting.updated_since(last_refresh_time - 1).each do |setting|
        value = (setting.deleted? ? NOT_DEFINED : setting.value)
        changed_settings[setting.key] = value
      end
      set_cache_values(start_time) { @cache.merge(changed_settings) }
    end

    # Check that cache has update to date data in it. If it doesn't, then sync the
    # cache with the database.
    def ensure_cache_up_to_date!
      if @last_refreshed.nil?
        # Abort if another thread is already calling load_settings
        previous_cache_id = @cache.object_id
        @lock.synchronize do
          return unless previous_cache_id == @cache.object_id
        end
        load_settings(Setting.storage.load_asynchronous?)
      elsif Time.now >= @next_check_at
        refresh(Setting.storage.load_asynchronous?)
      end
    end

    # Synchronized method for setting cache and sync meta data.
    def set_cache_values(refreshed_at_time, &block)
      @lock.synchronize do
        @last_refreshed = refreshed_at_time
        @refreshing = false
        @cache = block.call.freeze
      end
    end

    # Recusive method for creating a nested hash from delimited keys.
    def set_nested_hash_value(hash, key, value, current_depth, delimiter:, max_depth:)
      key, sub_key = ((max_depth && current_depth < max_depth) ? [key, nil] : key.split(delimiter, 2))
      if sub_key
        sub_hash = hash[key]
        unless sub_hash.is_a?(Hash)
          sub_hash = {}
          hash[key] = sub_hash
        end
        set_nested_hash_value(sub_hash, sub_key, value, current_depth + 1, delimiter: delimiter, max_depth: max_depth)
      else
        hash[key] = value
      end
    end

    # Recursively freeze a hash.
    def deep_freeze_hash(hash)
      hash.each_value do |value|
        deep_freeze_hash(value) if value.is_a?(Hash)
      end
      hash.freeze
    end
  end
end
