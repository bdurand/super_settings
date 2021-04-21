# frozen_string_literal: true

module SuperSettings
  class LocalCache

    attr_reader :ttl

    def initialize(ttl:)
      @ttl = ttl
      @cache = {}
      @lock = Mutex.new
      @last_refreshed = nil
      @next_check_at = Time.now + @ttl
      @refreshing = false
    end

    def load
      values = {}
      start_time = Time.now
      finder = SuperSettings::Setting.value_data.not_deleted
      finder.each do |setting|
        values[setting.key] = setting.value
      end
      @lock.synchronize do
        @last_refreshed = start_time
        @cache = values
      end
    end

    def [](key)
      refresh if Time.now >= @next_check_at
      key = key.to_s
      value = @cache[key]
      if value.nil? && !@cache.include?(key)
        start_time = Time.now
        value = SuperSettings::Setting.fetch(key)
        @lock.synchronize do
          @last_refreshed = start_time
          @cache[key] = value
        end
      end
      value
    end

    def inspect
      @cache.inspect
    end

    def include?(key)
      @cache.include?(key)
    end

    def size
      @cache.size
    end

    def clear
      @lock.synchronize do
        @cache = {}
        @last_refreshed = nil
        @next_check_at = Time.now + @ttl
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
        last_db_update = SuperSettings::Setting.last_updated_at
        if last_db_update.nil? || last_db_update >= last_refresh_time - 1
          merge_load(last_refresh_time)
        end
      ensure
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
      finder = SuperSettings::Setting.value_data.where("updated_at >= ?", last_refresh_time - 1)
      finder.each do |setting|
        values[setting.key] = setting.value
      end
      @lock.synchronize do
        @last_refreshed = start_time
        @cache = @cache.merge(values)
      end
    end
  end
end
