# frozen_string_literal: true

require "json"

# Redis implementation of the SuperSettings::Storage model.
module SuperSettings
  module Storage
    class RedisStorage
      include Storage

      SETTINGS_KEY = "SuperSettings.settings"
      UPDATED_KEY = "SuperSettings.order_by_updated_at"
      HISTORY_KEY = "SuperSettings.history"

      class HistoryItem
        include ActiveModel::Model

        extend ActiveModel::Callbacks
        define_model_callbacks :validation

        include History
        attr_accessor :key, :value, :changed_by, :created_at

        class << self
          def destroy_all
            # TODO
          end
        end

        def destroy
          # TODO
        end
      end

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
          redis.mget(SETTINGS_KEY, *keys).each do |json|
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

        def create!(attributes)
          setting = new(attributes)
          setting.save!
          setting
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
                Thread.current[:super_settings_transaction_records] = []
                block.call(multi_redis)
              end
              Thread.current[:super_settings_transaction_records].each do |record|
                record.run_callbacks(:commit)
              end
            ensure
              Thread.current[:super_settings_transaction_redis] = nil
              Thread.current[:super_settings_transaction_records] = nil
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

      def history(limit:, offset: 0)
        # TODO
      end

      def create_history(attributes)
        self.class.transaction do |redis|
          # TODO
        end
      end

      def save!
        raise RecordInvalid unless valid?

        self.class.transaction do |redis|
          run_callbacks(:save) do
            timestamp = Time.now
            self.created_at ||= timestamp
            self.updated_at = timestamp

            redis.hset(SETTINGS_KEY, key, payload_json)
            redis.zadd(UPDATED_KEY, timestamp.to_f, key)

            set_persisted!
          end
          Thread.current[:super_settings_transaction_records] << self
        end

        true
      end

      def reload
        self.attributes = JSON.parse(self.class.redis.hget(SETTINGS_KEY, key))
        self
      end

      def destroy
        self.class.redis.multi do |transaction|
          transaction.hdel(SETTINGS_KEY, key)
          transaction.zrem(UPDATED_KEY, key)
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

      def persisted?
        !!(defined?(@persisted) && @persisted)
      end

      protected

      def redact_history!
        # TODO
      end

      private

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
