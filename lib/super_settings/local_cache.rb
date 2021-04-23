# frozen_string_literal: true

module SuperSettings
  class LocalCache
    attr_reader :ttl

    def initialize(ttl:)
      @ttl = ttl
      @lock = Mutex.new
      reset
    end

    def [](key)
      ensure_cache_up_to_date!
      key = key.to_s
      value = @cache[key]
      if value.nil? && !@cache.include?(key)
        start_time = Time.now
        value = Setting.fetch(key)
        @lock.synchronize do
          @last_refreshed = start_time
          @cache = @cache.merge(key => value).freeze
        end
      end
      value
    end

    def include?(key)
      @cache.include?(key)
    end

    def size
      ensure_cache_up_to_date!
      @cache.size
    end

    def to_h
      ensure_cache_up_to_date!
      @cache
    end

    def loaded?
      !!@last_refreshed
    end

    def load_settings
      @lock.synchronize do
        @refreshing = true
        @next_check_at = Time.now + @ttl
      end
      begin
        values = {}
        start_time = Time.now
        finder = Setting.value_data
        finder.each do |setting|
          values[setting.key] = setting.value
        end
        set_cache_values(start_time) { values }
      ensure
        @refreshing = false
      end
    end

    def refresh
      last_refresh_time = @last_refreshed
      return if last_refresh_time.nil?
      return if @refreshing

      @lock.synchronize do
        return if @refreshing
        @next_check_at = Time.now + @ttl
        return if @cache.empty?
        @refreshing = true
      end

      begin
        last_db_update = Setting.last_updated_at
        if last_db_update.nil? || last_db_update >= last_refresh_time - 1
          merge_load(last_refresh_time)
        end
      ensure
        @refreshing = false
      end
    end

    def reset
      @lock.synchronize do
        @cache = {}.freeze
        @last_refreshed = nil
        @next_check_at = Time.now + @ttl
        @refreshing = false
      end
    end

    def ttl=(seconds)
      @lock.synchronize do
        @ttl = seconds
        @next_check_at = Time.now + @ttl if @next_check_at > Time.now + @ttl
      end
    end

    private

    def merge_load(last_refresh_time)
      values = {}
      start_time = Time.now
      finder = Setting.with_deleted.value_data.where("updated_at >= ?", last_refresh_time - 1)
      finder.each do |setting|
        values[setting.key] = setting.value
      end
      set_cache_values(start_time) { @cache.merge(values) }
    end

    def ensure_cache_up_to_date!
      if @last_refreshed.nil?
        # Abort if another thread has already calling load_settings
        previous_cache_id = @cache.object_id
        @lock.synchronize do
          return unless previous_cache_id == @cache.object_id
        end
        load_settings
      elsif Time.now >= @next_check_at
        refresh
      end
    end

    def set_cache_values(refreshed_at_time, &block)
      @lock.synchronize do
        @last_refreshed = refreshed_at_time
        @refreshing = false
        @cache = block.call.freeze
      end
    end
  end
end
