# frozen_string_literal: true

require "redis"

module SuperSettings
  module Storage
    # Redis implementation of the SuperSettings::Storage model.
    #
    # You must define the redis connection to use by setting the redis attribute on the class.
    # This can either be a +Redis+ object or a block that yields a +Redis+ object. You can use the
    # block form if you need to get the Redis object at runtime instead of having a static object.
    #
    # You can also use the [connection_pool]() gem to provide a pool of Redis connecions for
    # a multi-threaded application. The connection_pool gem is not a dependency of this gem,
    # so you would need to add it to your application dependencies to use it.
    #
    # @example
    #   SuperSettings::Storage::RedisStorage.redis = Redis.new(url: ENV["REDIS_URL"])
    #
    # @example
    #   SuperSettings::Storage::RedisStorage.redis = lambda { RedisClient.get(:settings) }
    #
    # @example
    #   SuperSettings::Storage::RedisStorage.redis = ConnectionPool.new(size: 5) { Redis.new(url: ENV["REDIS_URL"]) }
    class RedisStorage < StorageAttributes
      include Transaction

      SETTINGS_KEY = "SuperSettings.settings"
      UPDATED_KEY = "SuperSettings.order_by_updated_at"

      class HistoryStorage < HistoryAttributes
        HISTORY_KEY_PREFIX = "SuperSettings.history"

        class << self
          def find_all_by_key(key:, offset: 0, limit: nil)
            end_index = (limit.nil? ? -1 : offset + limit - 1)
            return [] unless end_index >= -1

            payloads = RedisStorage.with_redis { |redis| redis.lrange("#{HISTORY_KEY_PREFIX}.#{key}", offset, end_index) }
            payloads.collect do |json|
              record = new(JSON.parse(json))
              record.key = key.to_s
              record
            end
          end

          def create!(attributes)
            record = new(attributes)
            record.save!
            record
          end

          def destroy_all_by_key(key, redis)
            redis.del("#{HISTORY_KEY_PREFIX}.#{key}")
          end

          def redis_key(key)
            "#{HISTORY_KEY_PREFIX}.#{key}"
          end
        end

        def save!
          raise ArgumentError.new("Missing key") if Coerce.blank?(key)

          RedisStorage.transaction do |changes|
            changes << self
          end
        end

        def save_to_redis(redis)
          redis.lpush(self.class.redis_key(key), payload_json.to_json)
        end

        def created_at
          SuperSettings::Storage::RedisStorage.time_at_microseconds(super)
        end

        private

        def payload_json
          payload = {
            value: value,
            changed_by: changed_by,
            created_at: SuperSettings::Storage::RedisStorage.microseconds(created_at)
          }
          payload[:deleted] = true if deleted?
          payload
        end
      end

      class << self
        def all
          with_redis do |redis|
            redis.hgetall(SETTINGS_KEY).values.collect { |json| load_from_json(json) }
          end
        end

        def updated_since(time)
          min_score = microseconds(time)
          with_redis do |redis|
            keys = redis.zrangebyscore(UPDATED_KEY, min_score, "+inf")
            return [] if keys.empty?

            settings = []
            redis.hmget(SETTINGS_KEY, *keys).each do |json|
              setting = load_from_json(json) if json
              settings << setting if setting && setting.updated_at > time
            end
            settings
          end
        end

        def find_by_key(key)
          json = with_redis { |redis| redis.hget(SETTINGS_KEY, key) }
          return nil unless json

          record = load_from_json(json)
          record unless record.deleted?
        end

        def create_history(key:, changed_by:, created_at:, value: nil, deleted: false)
          HistoryStorage.create!(key: key, value: value, deleted: deleted, changed_by: changed_by, created_at: created_at)
        end

        def last_updated_at
          result = with_redis { |redis| redis.zrevrange(UPDATED_KEY, 0, 1, withscores: true).first }
          return nil unless result

          time_at_microseconds(result[1])
        end

        def destroy_all
          all.each(&:destroy)
        end

        attr_writer :redis

        def with_redis(&block)
          connection = (@redis.is_a?(Proc) ? @redis.call : @redis)
          if defined?(ConnectionPool) && connection.is_a?(ConnectionPool)
            connection.with(&block)
          else
            block.call(connection)
          end
        end

        def save_all(changes)
          with_redis do |redis|
            redis.multi do |multi_redis|
              changes.each do |object|
                object.save_to_redis(multi_redis)
              end
            end
          end
          true
        end

        def time_at_microseconds(time)
          TimePrecision.new(time, :microsecond).time
        end

        def microseconds(time)
          TimePrecision.new(time, :microsecond).to_f
        end

        protected

        def default_load_asynchronous?
          true
        end

        private

        def load_from_json(json)
          attributes = JSON.parse(json)
          setting = new(attributes)
          setting.persisted = true
          setting
        end
      end

      def initialize(*)
        @deleted = false
        @persisted = false
        super
      end

      def history(limit: nil, offset: 0)
        HistoryStorage.find_all_by_key(key: key, limit: limit, offset: offset).collect do |record|
          HistoryItem.new(key: key, value: record.value, changed_by: record.changed_by, created_at: record.created_at, deleted: record.deleted?)
        end
      end

      def save_to_redis(redis)
        redis.hset(SETTINGS_KEY, key, payload_json)
        redis.zadd(UPDATED_KEY, self.class.microseconds(updated_at), key)
      end

      def destroy
        self.class.with_redis do |redis|
          redis.multi do |multi_redis|
            multi_redis.hdel(SETTINGS_KEY, key)
            multi_redis.zrem(UPDATED_KEY, key)
            HistoryStorage.destroy_all_by_key(key, multi_redis)
          end
        end
      end

      def created_at
        self.class.time_at_microseconds(super)
      end

      def updated_at
        self.class.time_at_microseconds(super)
      end

      private

      def payload_json
        payload = {
          key: key,
          raw_value: raw_value,
          value_type: value_type,
          description: description,
          created_at: self.class.microseconds(created_at),
          updated_at: self.class.microseconds(updated_at)
        }
        payload[:deleted] = true if deleted?
        payload.to_json
      end
    end
  end
end
