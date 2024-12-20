# frozen_string_literal: true

module SuperSettings
  module Storage
    # This is an abstract storage class that provides support for storing settings in a JSON file.
    # The settings are stored in JSON as an array of hashes with each hash representing a setting.
    #
    # Setting history should be stored in separate JSON files per key and are loaded separately
    # from the main settings file.
    #
    # This class can be used as the base for any storage class where the settings are all stored
    # together in a single JSON payload.
    #
    # Subclasses must implement the following methods:
    # - self.all
    # - self.last_updated_at
    # - save!
    class JSONStorage < StorageAttributes
      include Transaction

      class HistoryStorage < HistoryAttributes
        class << self
          def create!(attributes)
            record = new(attributes)
            record.save!
            record
          end
        end

        def initialize(*)
          @storage = nil
          super
        end

        attr_writer :storage

        def created_at=(val)
          super(TimePrecision.new(val).time)
        end

        def save!
          raise ArgumentError.new("Missing key") if Coerce.blank?(key)

          @storage.transaction do |changes|
            changes << self
          end
        end
      end

      class << self
        def all
          parse_settings(settings_json_payload)
        end

        def updated_since(timestamp)
          all.select { |setting| setting.updated_at > timestamp }
        end

        def find_by_key(key)
          active.detect { |setting| setting.key == key }
        end

        def create_history(key:, changed_by:, created_at:, value: nil, deleted: false)
          HistoryStorage.create!(key: key, value: value, changed_by: changed_by, created_at: created_at, deleted: deleted, storage: self)
        end

        def save_all(changes)
          existing = {}
          parse_settings(settings_json_payload).each do |setting|
            existing[setting.key] = setting
          end

          history_items = []
          changes.each do |record|
            if record.is_a?(HistoryStorage)
              history_items << record
            else
              existing[record.key] = record
            end
          end

          settings = existing.values.sort_by(&:key)

          changed_histories = {}
          history_items.each do |history_item|
            setting = existing[history_item.key]
            next unless setting

            history = changed_histories[history_item.key]
            unless history
              history = setting.history.dup
              changed_histories[history_item.key] = history
            end
            history.unshift(history_item)
          end

          settings_json = JSON.dump(settings.collect(&:as_json))
          save_settings_json(settings_json)

          changed_histories.each do |setting_key, setting_history|
            ordered_history = setting_history.sort_by { |history_item| history_item.created_at }.reverse
            payload = ordered_history.collect do |history_item|
              {
                value: history_item.value,
                changed_by: history_item.changed_by,
                created_at: history_item.created_at.iso8601(6),
                deleted: history_item.deleted?
              }
            end
            history_json = JSON.dump(payload)
            save_history_json(setting_key, history_json)
          end
        end

        # Heper method to load settings from a JSON string.
        #
        # @param json [String] JSON string to parse.
        # @return [Array<SuperSettings::Storage::JSONStorage>] Array of settings.
        def parse_settings(json)
          return [] if Coerce.blank?(json)

          JSON.parse(json).collect do |attributes|
            setting = new(
              key: attributes["key"],
              raw_value: attributes["value"],
              description: attributes["description"],
              value_type: attributes["value_type"],
              updated_at: Time.parse(attributes["updated_at"]),
              created_at: Time.parse(attributes["created_at"]),
              deleted: attributes["deleted"]
            )
            setting.persisted = true
            setting
          end
        end

        protected

        # Subclasses must implement this method to return the JSON payload containing all of the
        # settings as a string.
        #
        # @return [String] JSON string.
        def settings_json_payload
          # :nocov:
          raise NotImplementedError
          # :nocov:
        end

        # Subclasses must implement this method to persist the JSON payload containing all of the
        # settings.
        #
        # @param json [String] JSON string to save.
        def save_settings_json(json)
          # :nocov:
          raise NotImplementedError
          # :nocov:
        end

        # Subclasses must implement this method to persist the JSON payload containing the history
        # records for a setting key.
        #
        # @param key [String] Setting key.
        # @param json [String] JSON string to save.
        # @return [void]
        def save_history_json(key, json)
          # :nocov:
          raise NotImplementedError
          # :nocov:
        end
      end

      def created_at=(val)
        super(TimePrecision.new(val).time)
      end

      def updated_at=(val)
        super(TimePrecision.new(val).time)
      end

      def history(limit: nil, offset: 0)
        history = fetch_history
        limit ||= history.length
        history[offset, limit].collect do |record|
          HistoryItem.new(key: key, value: record.value, changed_by: record.changed_by, created_at: record.created_at, deleted: record.deleted?)
        end
      end

      def as_json
        {
          key: key,
          value: raw_value,
          value_type: value_type,
          description: description,
          created_at: created_at&.iso8601(6),
          updated_at: updated_at&.iso8601(6),
          deleted: deleted?
        }
      end

      protected

      # Subclasses must implement this method to return the JSON payload containing all of the
      # history records for the setting key. The payload must be an array that contains hashes
      # with the keys "value", "changed_by", "deleted", and "created_at".
      def fetch_history_json
        raise NotImplementedError
      end

      private

      def fetch_history
        json = fetch_history_json
        history_payload = Coerce.blank?(json) ? [] : JSON.parse(json)

        history_items = history_payload.collect do |attributes|
          HistoryStorage.new(
            key: key,
            value: attributes["value"],
            changed_by: attributes["changed_by"],
            created_at: Time.parse(attributes["created_at"]),
            deleted: attributes["deleted"]
          )
        end

        history_items.sort_by(&:created_at).reverse
      end
    end
  end
end
