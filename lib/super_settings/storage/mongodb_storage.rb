# frozen_string_literal: true

require "mongo"

module SuperSettings
  module Storage
    # MongoDB implementation of the SuperSettings::Storage model.
    #
    # You must define the connection URL to use by setting the `url` or `mongodb` attribute on the class.
    #
    # @example
    #   SuperSettings::Storage::MongoDBStorage.url = "mongodb://user:password@localhost:27017/super_settings"
    #
    # @example
    #  SuperSettings::Storage::MongoDBStorage.mongodb = Mongo::Client.new("mongodb://user:password@localhost:27017/super_settings")
    class MongoDBStorage < StorageAttributes
      include Storage
      include Transaction

      DEFAULT_COLLECTION_NAME = "super_settings"

      @mongodb = nil
      @url = nil
      @url_hash = @url.hash
      @collection_name = DEFAULT_COLLECTION_NAME
      @mutex = Mutex.new

      class HistoryStorage < HistoryAttributes
        class << self
          def create!(attributes)
            record = new(attributes)
            record.save!
            record
          end
        end

        def created_at=(value)
          super(TimePrecision.new(value, :millisecond).time)
        end

        def save!
          raise ArgumentError.new("Missing key") if Coerce.blank?(key)

          MongoDBStorage.transaction do |changes|
            changes << self
          end
        end

        def as_bson
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
        attr_writer :url, :mongodb
        attr_accessor :collection_name

        def mongodb
          if @mongodb.nil? || @url_hash != @url.hash
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
          mongodb[collection_name]
        end

        def updated_since(time)
          time = TimePrecision.new(time, :millisecond).time
          settings_collection.find(updated_at: {"$gt": time}).projection(history: 0).sort({updated_at: -1}).collect do |attributes|
            record = new(attributes)
            record.persisted = true
            record
          end
        end

        def all
          settings_collection.find.projection(history: 0).collect do |attributes|
            record = new(attributes)
            record.persisted = true
            record
          end
        end

        def find_by_key(key)
          query = {
            key: key,
            deleted: false
          }
          record = settings_collection.find(query).projection(history: 0).first
          new(record) if record
        end

        def last_updated_at
          last_updated_setting = settings_collection.find.projection(updated_at: 1).sort(updated_at: -1).limit(1).first
          last_updated_setting["updated_at"] if last_updated_setting
        end

        def create_history(key:, changed_by:, created_at:, value: nil, deleted: false)
          HistoryStorage.create!(key: key, value: value, changed_by: changed_by, created_at: created_at, deleted: deleted)
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

        def upsert(record)
          update = {"$setOnInsert": {key: record.key}}
          if record.is_a?(MongoDBStorage::HistoryStorage)
            update["$push"] = {history: record.as_bson}
          else
            update["$set"] = record.as_bson.except(:key)
          end

          {
            update_one: {
              filter: {key: record.key},
              update: update,
              upsert: true
            }
          }
        end

        def create_indexes!(client)
          collection = client[collection_name]
          collection_exists = client.database.collection_names.include?(collection.name)
          existing_indexes = (collection_exists ? collection.indexes.to_a : [])

          unique_key_index = {key: 1}
          unless existing_indexes.any? { |index| index["key"] == unique_key_index }
            collection.indexes.create_one(unique_key_index, unique: true)
          end

          updated_at_index = {updated_at: -1}
          unless existing_indexes.any? { |index| index["key"] == updated_at_index }
            collection.indexes.create_one(updated_at_index)
          end

          history_created_at_desc_index = {key: 1, "history.created_at": -1}
          unless existing_indexes.any? { |index| index["key"] == history_created_at_desc_index }
            collection.indexes.create_one(history_created_at_desc_index)
          end
        end
      end

      def history(limit: nil, offset: 0)
        pipeline = [
          {
            "$match": {key: key}
          },
          {
            "$addFields": {
              history: {
                "$sortArray": {
                  input: "$history",
                  sortBy: {created_at: -1}
                }
              }
            }
          }
        ]

        if limit || offset > 0
          pipeline << {
            "$addFields": {
              history: {
                "$slice": ["$history", offset, (limit || {"$size": "$history"})]
              }
            }
          }
        end

        pipeline << {
          "$project": {
            _id: 0,
            history: 1
          }
        }

        record = self.class.settings_collection.aggregate(pipeline).to_a.first
        return [] unless record && record["history"].is_a?(Array)

        record["history"].collect do |record|
          HistoryItem.new(key: key, value: record["value"], changed_by: record["changed_by"], created_at: record["created_at"], deleted: record["deleted"])
        end
      end

      def created_at=(val)
        super(TimePrecision.new(val, :millisecond).time)
      end

      def updated_at=(val)
        super(TimePrecision.new(val, :millisecond).time)
      end

      def destroy
        settings_collection.delete_one(key: key)
      end

      def as_bson
        {
          key: key,
          raw_value: raw_value,
          value_type: value_type,
          description: description,
          created_at: created_at,
          updated_at: updated_at,
          deleted: deleted?
        }
      end
    end

    def created_at=(val)
      super(TimePrecision.new(val, :millisecond).time)
    end

    def updated_at=(val)
      super(TimePrecision.new(val, :millisecond).time)
    end
  end
end
