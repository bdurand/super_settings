# frozen_string_literal: true

module SuperSettings
  class LocalCache
    NOT_DEFINED = Object.new.freeze
    private_constant :NOT_DEFINED

    attr_reader :refresh_interval

    def initialize(refresh_interval:, track_last_used: false)
      @refresh_interval = refresh_interval
      @lock = Mutex.new
      @last_used_drift = rand * 10
      @track_last_used = track_last_used
      reset
    end

    def [](key)
      ensure_cache_up_to_date!
      key = key.to_s
      value, last_used_at = @cache[key]
      if value.nil? && !@cache.include?(key)
        if @refreshing
          value = NOT_DEFINED
        else
          setting = Setting.find_by(key: key)
          value = (setting ? setting.value : NOT_DEFINED)
          last_used_at = setting&.last_used_at.to_f
          @lock.synchronize do
            @cache = @cache.merge(key => [value, last_used_at]).freeze
          end
        end
      end
      return nil if value == NOT_DEFINED
      update_last_used_at!(key, last_used_at)
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
      hash = {}
      @cache.each do |key, data|
        value, _ = data
        hash[key] = value unless value == NOT_DEFINED
      end
      hash
    end

    def loaded?
      !!@last_refreshed
    end

    def load_settings
      return if @refreshing

      @lock.synchronize do
        return if @refreshing
        @refreshing = true
        @next_check_at = Time.now + @refresh_interval
      end

      begin
        values = {}
        start_time = Time.now
        finder = Setting.runtime_data
        finder.each do |setting|
          values[setting.key] = [setting.value, setting.last_used_at.to_f]
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
        @next_check_at = Time.now + @refresh_interval
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
        @next_check_at = Time.now + @refresh_interval
        @refreshing = false
      end
    end

    def refresh_interval=(seconds)
      @lock.synchronize do
        @refresh_interval = seconds
        @next_check_at = Time.now + @refresh_interval if @next_check_at > Time.now + @refresh_interval
      end
    end

    def track_last_used=(value)
      @track_last_used = !!value
    end

    def track_last_used?
      @track_last_used
    end

    private

    def merge_load(last_refresh_time)
      changed_settings = {}
      start_time = Time.now
      finder = Setting.with_deleted.runtime_data.where("updated_at >= ?", last_refresh_time - 1)
      finder.each do |setting|
        value = (setting.deleted? ? NOT_DEFINED : setting.value)
        changed_settings[setting.key] = [value, setting.last_used_at.to_f]
      end
      set_cache_values(start_time) { @cache.merge(changed_settings) }
    end

    def ensure_cache_up_to_date!
      if @last_refreshed.nil?
        # Abort if another thread is already calling load_settings
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

    def update_last_used_at!(key, last_used_at)
      return unless track_last_used?
      if last_used_at + 3600 + @last_used_drift < Time.now.to_f
        begin
          Setting.where(key: key).update_all(last_used_at: Time.now)
        rescue
          @lock.synchronize do
            entry = @cache[key]
            entry[1] = Time.now.to_f if entry
          end
        end
      end
    end
  end
end
