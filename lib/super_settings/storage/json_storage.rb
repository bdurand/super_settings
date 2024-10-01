# frozen_string_literal: true

require "json"

module SuperSettings
  module Storage
    # This is an abstract storage class that provides support for storing settings in a JSON file.
    # The settings are stored in JSON as an array of hashes with each hash representing a setting.
    # This class can be used as the base for any storage class where the settings are all stored
    # together in a single JSON payload.
    #
    # Subclasses must implement the following methods:
    # - self.all
    # - self.last_updated_at
    # - save!
    class JSONStorage
      include Storage
      include Transaction

      class HistoryStorage
        include SuperSettings::Attributes

        attr_accessor :key, :value, :changed_by, :created_at
        attr_writer :deleted

        def initialize(*)
          @key = nil
          @value = nil
          @changed_by = nil
          @created_at = nil
          @deleted = false
          super
        end

        def deleted?
          !!@deleted
        end

        def as_json
          attributes = {
            value: value,
            changed_by: changed_by,
            created_at: created_at
          }
          attributes[:deleted] = true if deleted?
          attributes
        end
      end

      attr_accessor :key, :raw_value, :description, :value_type, :updated_at, :created_at
      attr_writer :deleted

      class << self
        def all
          parse(json_payload)
        end

        def updated_since(timestamp)
          all.select { |setting| setting.updated_at >= timestamp }
        end

        def find_by_key(key)
          active.detect { |setting| setting.key == key }
        end

        def save_all(changes)
          existing = {}
          parse(json_payload).each do |setting|
            existing[setting.key] = setting
          end

          changes.each do |setting|
            existing[setting.key] = setting
          end

          settings = existing.values.sort_by(&:key)
          settings.each { |setting| setting.history.sort_by!(&:created_at).reverse! }

          json = to_json(settings)
          save_json(json)
        end

        # Heper method to load settings from a JSON string.
        #
        # @param json [String] JSON string to parse.
        # @return [Array<SuperSettings::Storage::JSONStorage>] Array of settings.
        def parse(json)
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

            if attributes.include?("history")
              history_attributes = attributes["history"].collect do |attr|
                {
                  value: attr["value"],
                  changed_by: attr["changed_by"],
                  created_at: Time.parse(attr["created_at"]),
                  deleted: attr["deleted"]
                }
              end
              history_attributes.each do |attr|
                setting.create_history(**attr)
              end
            end

            setting.persisted = true
            setting
          end
        end

        # Helper method to convert settings to a JSON string.
        #
        # @param settings [Array<SuperSettings::Storage::JSONStorage>] Array of settings.
        # @return [String] JSON string.
        def to_json(settings)
          JSON.dump(settings.collect(&:as_json))
        end

        protected

        # Subclasses must implement this method to return the JSON payload containing all of the
        # settings as a string.
        #
        # @return [String] JSON string.
        def json_payload
          # :nocov:
          raise NotImplementedError
          # :nocov:
        end

        # Subclasses must implement this method to persist the JSON payload containing all of the
        # settings.
        #
        # @param json [String] JSON string to save.
        def save_json(json)
          # :nocov:
          raise NotImplementedError
          # :nocov:
        end
      end

      def initialize(attributes = nil)
        @key = nil
        @raw_value = nil
        @description = nil
        @value_type = nil
        @deleted = false
        @updated_at = nil
        @created_at = nil
        @persisted = false
        @history = []
        super
      end

      def deleted?
        !!@deleted
      end

      def persisted?
        !!@persisted
      end

      def history(limit: nil, offset: 0)
        limit ||= @history.length
        @history[offset, limit].collect do |record|
          HistoryItem.new(key: key, value: record.value, changed_by: record.changed_by, created_at: record.created_at, deleted: record.deleted?)
        end
      end

      def create_history(changed_by:, created_at:, value: nil, deleted: false)
        new_history = HistoryStorage.new(key: key, value: value, changed_by: changed_by, created_at: created_at, deleted: deleted)
        index = @history.bsearch_index { |element| new_history.created_at >= element.created_at }
        index ||= @history.size
        @history.insert(index, new_history)
        new_history
      end

      def as_json
        attributes = {
          key: key,
          value: raw_value,
          value_type: value_type,
          description: description,
          created_at: created_at,
          updated_at: updated_at,
          history: @history.collect(&:as_json)
        }
        attributes[:deleted] = true if deleted?
        attributes
      end
    end
  end
end
