# frozen_string_literal: true

require "json"

# Redis implementation of the SuperSettings::Storage model.
#
# You must define the redis connection to use by setting the redis attribute on the class.
# This can either be a `Redis` object or a block that yields a `Redis` object. You can use the
# block form if you need to get the `Redis` object at runtime instead of having a static object.
#
# ```ruby
# SuperSettings::Storage::RedisStorage.redis = Redis.new(url: ENV["REDIS_URL"])
#
# SuperSettings::Storage::RedisStorage.redis = lambda { RedisClient.get(:settings) }
# ```
module SuperSettings
  module Storage
    class RedisStorage
      include Storage

      SETTINGS_KEY = "SuperSettings.settings"
      UPDATED_KEY = "SuperSettings.order_by_updated_at"

      class HistoryStorage
        HISTORY_KEY_PREFIX = "SuperSettings.history"

        include ActiveModel::Model

        attr_accessor :key, :value, :changed_by, :deleted
        attr_reader :created_at

        class << self
          def find_all_by_key(key:, offset: 0, limit: nil)
            end_index = (limit.nil? ? -1 : offset + limit - 1)
            return [] unless end_index >= -1
            payloads = RedisStorage.redis.lrange("#{HISTORY_KEY_PREFIX}.#{key}", offset, end_index)
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

          def destroy_all_by_key(key)
            RedisStorage.redis.del("#{HISTORY_KEY_PREFIX}.#{key}")
          end

          def redis_key(key)
            "#{HISTORY_KEY_PREFIX}.#{key}"
          end
        end

        def created_at=(val)
          @created_at = (val.is_a?(Numeric) ? Time.at(val) : val&.to_time)
        end

        def save!
          raise ArgumentError.new("Missing key") if key.blank?
          RedisStorage.transaction do |redis|
            redis.lpush(self.class.redis_key(key), payload_json.to_json)
          end
        end

        def deleted?
          !!(defined?(@deleted) && @deleted)
        end

        private

        def payload_json
          payload = {
            value: value,
            changed_by: changed_by,
            created_at: created_at.to_f
          }
          payload[:deleted] = true if deleted?
          payload
        end
      end

      include ActiveModel::Model

      attr_reader :key, :raw_value, :description, :value_type, :updated_at, :created_at
      attr_accessor :changed_by

      class << self
        def all_settings
          redis.hgetall(SETTINGS_KEY).values.collect { |json| load_from_json(json) }
        end

        def updated_since(time)
          min_score = time.to_time.to_f
          keys = redis.zrangebyscore(UPDATED_KEY, min_score, "+inf")
          return [] if keys.empty?

          settings = []
          redis.hmget(SETTINGS_KEY, *keys).each do |json|
            settings << load_from_json(json) if json
          end
          settings
        end

        def find_by_key(key)
          json = redis.hget(SETTINGS_KEY, key)
          return nil unless json
          load_from_json(json)
        end

        def last_updated_at
          result = redis.zrevrange(UPDATED_KEY, 0, 1, withscores: true).first
          return nil unless result
          Time.at(result[1])
        end

        def destroy_all
          all_settings.each(&:destroy)
        end

        attr_writer :redis

        def redis
          @redis.is_a?(Proc) ? @redis.call : @redis
        end

        def transaction(&block)
          if Thread.current[:super_settings_transaction_redis]
            block.call(Thread.current[:super_settings_transaction_redis])
          else
            begin
              redis.multi do |multi_redis|
                Thread.current[:super_settings_transaction_redis] = multi_redis
                Thread.current[:super_settings_transaction_after_commit] = []
                block.call(multi_redis)
              end
              after_commits = Thread.current[:super_settings_transaction_after_commit]
              Thread.current[:super_settings_transaction_after_commit] = nil
              after_commits.each(&:call)
            ensure
              Thread.current[:super_settings_transaction_redis] = nil
              Thread.current[:super_settings_transaction_after_commit] = nil
            end
          end
        end

        private

        def load_from_json(json)
          attributes = JSON.parse(json)
          setting = new(attributes)
          setting.send(:set_persisted!)
          setting
        end
      end

      def history(limit: nil, offset: 0)
        HistoryStorage.find_all_by_key(key: key, limit: limit, offset: offset).collect do |record|
          HistoryItem.new(key: key, value: record.value, changed_by: record.changed_by, created_at: record.created_at, deleted: record.deleted?)
        end
      end

      def create_history(changed_by:, created_at:, value: nil, deleted: false)
        HistoryStorage.create!(key: key, value: value, deleted: deleted, changed_by: changed_by, created_at: created_at)
      end

      def store!
        self.updated_at ||= Time.now
        self.created_at ||= updated_at
        self.class.transaction do |redis|
          redis.hset(SETTINGS_KEY, key, payload_json)
          redis.zadd(UPDATED_KEY, updated_at.to_f, key)
          set_persisted!
        end
        true
      end

      def reload
        assign_attributes(JSON.parse(self.class.redis.hget(SETTINGS_KEY, key)))
        self
      end

      def destroy
        self.class.transaction do |redis|
          redis.hdel(SETTINGS_KEY, key)
          redis.zrem(UPDATED_KEY, key)
          HistoryStorage.destroy_all_by_key(key)
        end
      end

      def key=(value)
        @key = (value.blank? ? nil : value.to_s)
      end

      def raw_value=(value)
        @raw_value = (value.blank? ? nil : value.to_s)
      end

      def value_type=(value)
        @value_type = (value.blank? ? nil : value.to_s)
      end

      def description=(value)
        @description = (value.blank? ? nil : value.to_s)
      end

      def deleted=(value)
        @deleted = BooleanParser.cast(value)
      end

      def created_at=(value)
        @created_at = (value.is_a?(Numeric) ? Time.at(value) : value&.to_time)
      end

      def updated_at=(value)
        @updated_at = (value.is_a?(Numeric) ? Time.at(value) : value&.to_time)
      end

      def deleted?
        !!(defined?(@deleted) && @deleted)
      end

      def stored?
        !!(defined?(@persisted) && @persisted)
      end

      protected

      def redact_history!
        after_commit do
          histories = HistoryStorage.find_all_by_key(key: key)
          histories.each { |item| item.value = nil }
          self.class.transaction do
            HistoryStorage.destroy_all_by_key(key)
            histories.reverse.each(&:save!)
          end
        end
      end

      private

      def after_commit(&block)
        if Thread.current[:super_settings_transaction_after_commit]
          Thread.current[:super_settings_transaction_after_commit] << block
        else
          block.call
        end
      end

      def set_persisted!
        @persisted = true
      end

      def payload_json
        payload = {
          key: key,
          raw_value: raw_value,
          value_type: value_type,
          description: description,
          created_at: created_at.to_f,
          updated_at: updated_at.to_f
        }
        payload[:deleted] = true if deleted?
        payload.to_json
      end
    end
  end
end
