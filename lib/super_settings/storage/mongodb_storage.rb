# frozen_string_literal: true

require "mongo"

module SuperSettings
  module Storage
    # MongoDB implementation of the SuperSettings::Storage model.
    #
    # You must define the connection URL to use by setting the `url` attribute on the class.
    #
    # @example
    #   SuperSettings::Storage::MongoDBStorage.url = "mongodb://user:password@localhost:27017/super_settings"
    class MongoDBStorage < StorageAttributes
      include Storage
      include Transaction

      @mongodb = nil
      @url_hash = nil
      @mutex = Mutex.new

      class HistoryStorage < HistoryAttributes
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

      class << self
        attr_writer :url

        def mongodb
          unless @url_hash == @url.hash
            @mutex.synchronize do
              unless @url_hash == @url.hash
                @url_hash = @url.hash
                @mongodb = Mongo::Client.new(@url)
                create_indexes!(@mongodb)
              end
            end
          end
          @mongodb
        end

        def settings_collection
          mongodb["settings"]
        end

        def updated_since(time)
          settings_collection.find(updated_at: {"$gt": time}).sort({updated_at: -1}).collect do |attributes|
            record = new(attributes)
            record.persisted = true
            record
          end
        end

        def all
          settings_collection.find.collect do |attributes|
            record = new(attributes)
            record.persisted = true
            record
          end
        end

        def find_by_key(key)
          query = {
            key: key,
            "$or": [{deleted: {"$exists": false}}, {deleted: {"$ne": true}}]
          }
          record = settings_collection.find(query).first
          new(record) if record
        end

        def last_updated_at
          last_updated_setting = settings_collection.find.sort(updated_at: -1).limit(1).first
          last_updated_setting["updated_at"] if last_updated_setting
        end

        def destroy_all
          settings_collection.delete_many({})
        end

        def save_all(changes)
          upserts = changes.collect { |setting| upsert(setting) }
          settings_collection.bulk_write(upserts)
          true
        end

        protected

        def default_load_asynchronous?
          true
        end

        private

        def upsert(setting)
          doc = setting.as_json
          {
            update_one: {
              filter: {key: setting.key},
              update: {
                "$set": doc.except(:key),
                "$setOnInsert": {key: setting.key}
              },
              upsert: true
            }
          }
        end

        def create_indexes!(client)
          collection = client["settings"]
          collection_exists = client.database.collection_names.include?("settings")
          existing_indexes = (collection_exists ? collection.indexes.to_a : [])

          unique_key_index = {key: 1}
          unless existing_indexes.any? { |index| index["key"] == unique_key_index }
            collection.indexes.create_one(unique_key_index, unique: true)
          end

          updated_at_desc_index = {updated_at: -1}
          unless existing_indexes.any? { |index| index["key"] == updated_at_desc_index }
            collection.indexes.create_one(updated_at_desc_index)
          end
        end
      end

      def initialize(*)
        @history = []
        super
      end

      def history(limit: nil, offset: 0)
        limit ||= @history.length
        @history[offset, limit].collect do |record|
          HistoryItem.new(key: key, value: record.value, changed_by: record.changed_by, created_at: record.created_at, deleted: record.deleted?)
        end
      end

      def create_history(changed_by:, created_at:, value: nil, deleted: false)
        @history.sort! { |a, b| b.created_at <=> a.created_at }
        new_history = HistoryStorage.new(key: key, value: value, changed_by: changed_by, created_at: created_at, deleted: deleted)
        index = @history.bsearch_index { |element| new_history.created_at >= element.created_at }
        index ||= @history.size
        @history.insert(index, new_history)
        new_history
      end

      def destroy
        settings_collection.delete_one(key: key)
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
