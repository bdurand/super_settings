# frozen_string_literal: true

require_relative "super_settings/configuration"
require_relative "super_settings/local_cache"
require_relative "super_settings/version"

if defined?(Rails::Engine)
  require_relative "super_settings/engine"
  ActiveSupport.on_load(:active_record) do
    require_relative "super_settings/setting"
  end
else
  require "active_record"
  require "active_support/cache"
  require_relative "super_settings/setting"
end

module SuperSettings

  DEFAULT_CACHE_TTL = 5.0

  BOOLEAN_PARSER = ActiveModel::Type::Boolean.new

  class << self
    def ttl=(value)
      local_cache.ttl = value
    end

    def get(key, default = nil)
      val = local_cache[key]
      val.nil? ? default : val.to_s
    end

    def integer(key, default = nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_i
    end

    def float(key, default = nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_f
    end

    def enabled?(key, default = false)
      val = local_cache[key]
      val.nil? ? BOOLEAN_PARSER.cast(default) : !!val
    end

    def datetime(key, default = nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_time
    end

    def array(key, default = nil)
      val = local_cache[key]
      Array(val.nil? ? default : val).map { |v| v&.to_s }
    end

    def load
      local_cache.load
    end

    def refresh
      local_cache.refresh
    end

    def clear_cache
      local_cache.clear
    end

    def cache_inspect
      local_cache.inspect
    end

    def configure(&block)
      Configuration.instance.defer(&block)
    end

    private

    def local_cache
      @local_cache ||= LocalCache.new(ttl: DEFAULT_CACHE_TTL)
    end
  end

end
