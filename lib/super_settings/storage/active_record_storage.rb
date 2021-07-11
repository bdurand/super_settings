# frozen_string_literal: true

module SuperSettings
  module Storage
    # ActiveRecord implementation of the SuperSettings::Storage model.
    #
    # To use this model, you must run the migration included with the gem. The migration
    # can be installed with `rake app:super_settings:install:migrations` if the gem is mounted
    # as an engine in a Rails application.
    class ActiveRecordStorage
      # Base class that the models extend from.
      class ApplicationRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      class Model < ApplicationRecord
        self.table_name = "super_settings"

        has_many :history_items, class_name: "SuperSettings::Storage::ActiveRecordStorage::HistoryModel", foreign_key: :key, primary_key: :key
      end

      class HistoryModel < ApplicationRecord
        self.table_name = "super_settings_histories"

        # Since these models are created automatically on a callback, ensure that the data will
        # fit into the database columns since we can't handle any validation errors.
        before_validation do
          self.changed_by = changed_by.to_s[0, 150] if changed_by.present?
        end
      end

      include Storage

      class << self
        def all
          if Model.table_exists?
            Model.all.collect { |model| new(model) }
          else
            []
          end
        end

        def active
          if Model.table_exists?
            Model.where(deleted: false).collect { |model| new(model) }
          else
            []
          end
        end

        def updated_since(time)
          if Model.table_exists?
            Model.where("updated_at > ?", time).collect { |model| new(model) }
          else
            []
          end
        end

        def find_by_key(key)
          model = Model.where(deleted: false).find_by(key: key) if Model.table_exists?
          new(model) if model
        end

        def last_updated_at
          if Model.table_exists?
            Model.maximum(:updated_at)
          end
        end

        def with_connection(&block)
          Model.connection_pool.with_connection(&block)
        end

        def transaction(&block)
          Model.transaction(&block)
        end
      end

      delegate :key, :key=, :raw_value, :raw_value=, :value_type, :value_type=, :description, :description=,
        :deleted?, :deleted=, :updated_at, :updated_at=, :created_at, :created_at=, :persisted?, :save!,
        to: :@model

      def initialize(attributes = {})
        @model = if attributes.is_a?(Model)
          attributes
        else
          Model.new(attributes)
        end
      end

      def history(limit: nil, offset: 0)
        finder = @model.history_items.order(id: :desc).offset(offset)
        finder = finder.limit(limit) if limit
        finder.collect do |record|
          HistoryItem.new(key: key, value: record.value, changed_by: record.changed_by, created_at: record.created_at, deleted: record.deleted?)
        end
      end

      def create_history(changed_by:, created_at:, value: nil, deleted: false)
        history_attributes = {value: value, deleted: deleted, changed_by: changed_by, created_at: created_at}
        if @model.persisted?
          @model.history_items.create!(history_attributes)
        else
          @model.history_items.build(history_attributes)
        end
      end

      protected

      def redact_history!
        @model.history_items.update_all(value: nil)
      end
    end
  end
end
