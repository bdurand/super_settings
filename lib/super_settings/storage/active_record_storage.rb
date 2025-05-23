# frozen_string_literal: true

module SuperSettings
  module Storage
    # ActiveRecord implementation of the SuperSettings::Storage model.
    #
    # To use this model, you must run the migration included with the gem. If the gem
    # is mounted as an engine in a Rails applicationThe migration can be installed with
    #
    # @example
    #   rake app:super_settings:install:migrations
    class ActiveRecordStorage
      autoload :ApplicationRecord, File.join(__dir__, "active_record_storage/models")
      autoload :Model, File.join(__dir__, "active_record_storage/models")
      autoload :HistoryModel, File.join(__dir__, "active_record_storage/models")

      include Storage

      class << self
        def all
          if Model.available?
            Model.all.collect { |model| new(model) }
          else
            []
          end
        end

        def active
          if Model.available?
            Model.where(deleted: false).collect { |model| new(model) }
          else
            []
          end
        end

        def updated_since(time)
          if Model.available?
            Model.where("updated_at > ?", time).collect { |model| new(model) }
          else
            []
          end
        end

        def find_by_key(key)
          model = Model.where(deleted: false).find_by(key: key) if Model.available?
          new(model) if model
        end

        def last_updated_at
          if Model.available?
            Model.maximum(:updated_at)
          end
        end

        def create_history(key:, changed_by:, created_at:, value: nil, deleted: false)
          HistoryModel.create!(key: key, value: value, deleted: deleted, changed_by: changed_by, created_at: created_at)
        end

        def with_connection(&block)
          if Model.available?
            Model.connection_pool.with_connection(&block)
          else
            yield
          end
        end

        def transaction(&block)
          if Model.available?
            Model.transaction(&block)
          else
            yield
          end
        end

        def destroy_all
          Model.transaction do
            Model.delete_all
            HistoryModel.delete_all
          end
        end

        protected

        # Only load settings asynchronously if there is an extra database connection left in the
        # connection pool or if the configuration has explicitly allowed it.
        def default_load_asynchronous?
          Model.connection_pool.size > Thread.list.size
        end
      end

      delegate :key, :key=, :raw_value, :raw_value=, :value_type, :value_type=, :description, :description=,
        :deleted?, :deleted=, :updated_at, :updated_at=, :created_at, :created_at=, :persisted?,
        to: :@model

      def initialize(attributes = {})
        @model = if attributes.is_a?(Model)
          attributes
        else
          Model.new(attributes)
        end
      end

      def save!
        # Check if another record with the same key exists. If it does, then we need to update
        # that record instead and delete the current one.
        duplicate = @model.class.find_by(key: @model.key)
        if duplicate.nil? || duplicate == @model
          @model.save!
        else
          duplicate.raw_value = @model.raw_value
          duplicate.value_type = @model.value_type
          duplicate.description = @model.description
          duplicate.deleted = @model.deleted

          @model.transaction do
            if @model.persisted?
              @model.reload.update!(deleted: true)
            end
            duplicate.save!
          end
          @model = duplicate
        end
      end

      def history(limit: nil, offset: 0)
        finder = @model.history_items.order(id: :desc).offset(offset)
        finder = finder.limit(limit) if limit
        finder.collect do |record|
          HistoryItem.new(key: key, value: record.value, changed_by: record.changed_by, created_at: record.created_at, deleted: record.deleted?)
        end
      end
    end
  end
end
