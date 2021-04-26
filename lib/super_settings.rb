# frozen_string_literal: true

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

module SuperSettings
  DEFAULT_CACHE_TTL = 5.0

  class << self
    def ttl=(value)
      local_cache.ttl = value
    end

    def get(key, default: nil)
      val = local_cache[key]
      val.nil? ? default : val.to_s
    end

    def integer(key, default: nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_i
    end

    def float(key, default: nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_f
    end

    def enabled?(key, default: false)
      val = local_cache[key]
      val.nil? ? BooleanParser.cast(default) : !!val
    end

    def datetime(key, default: nil)
      val = local_cache[key]
      (val.nil? ? default : val)&.to_time
    end

    def array(key, default: nil)
      val = local_cache[key]
      Array(val.nil? ? default : val).map { |v| v&.to_s }
    end

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

    def load_settings
      local_cache.load_settings
    end

    def refresh_settings
      local_cache.refresh
    end

    def clear_cache
      local_cache.reset
    end

    def configure(&block)
      Configuration.instance.defer(&block)
    end

    def loaded?
      local_cache.loaded?
    end

    private

    def local_cache
      @local_cache ||= LocalCache.new(ttl: DEFAULT_CACHE_TTL)
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
