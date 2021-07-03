# frozen_string_literal: true

module SuperSettings
  # Base class that the models extend from.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  module Storage
    # ActiveRecord implementation of the SuperSettings::Storage model.
    #
    # To use this model, you must run the migration included with the gem. The migration
    # can be installed with `rake app:super_settings:install:migrations` if the gem is mounted
    # as an engine in a Rails application.
    class ActiveRecordStorage < ApplicationRecord
      self.table_name = "super_settings"

      include Storage

      class HistoryStorage < ApplicationRecord
        self.table_name = "super_settings_histories"

        # Since these models are created automatically on a callback, ensure that the data will
        # fit into the database columns since we can't handle any validation errors.
        before_validation do
          self.changed_by = changed_by.to_s[0, 150] if changed_by.present?
        end
      end

      has_many :history_items, class_name: "#{name}::HistoryStorage", foreign_key: :key, primary_key: :key

      class << self
        def ready?
          table_exists?
        end

        def all_settings
          all.to_a
        end

        def active_settings
          where(deleted: false).to_a
        end

        def updated_since(time)
          where("updated_at > ?", time).to_a
        end

        def find_by_key(key)
          where(deleted: false).find_by(key: key)
        end

        def last_updated_at
          maximum(:updated_at)
        end

        def save_settings!(settings)
          transaction do
            settings.each do |setting|
              setting.save!
            end
          end
        end

        def with_connection(&block)
          ActiveRecord::Base.connection_pool.with_connection { yield }
        end
      end

      def key
        self[:key]
      end

      def key=(val)
        self[:key] = val
      end

      def raw_value
        self[:raw_value]
      end

      def raw_value=(val)
        self[:raw_value] = val
      end

      def value_type
        self[:value_type]
      end

      def value_type=(val)
        self[:value_type] = val
      end

      def description
        self[:description]
      end

      def description=(val)
        self[:description] = val
      end

      def deleted?
        !!self[:deleted]
      end

      def deleted=(val)
        self[:deleted] = val
      end

      def updated_at
        self[:updated_at]
      end

      def updated_at=(val)
        self[:updated_at] = val
      end

      def created_at
        self[:created_at]
      end

      def created_at=(val)
        self[:created_at] = val
      end

      alias_method :stored?, :persisted?

      alias_method :store!, :save!

      def history(limit: nil, offset: 0)
        finder = history_items.order(id: :desc).offset(offset)
        finder = finder.limit(limit) if limit
        finder.collect do |record|
          HistoryItem.new(key: key, value: record.value, changed_by: record.changed_by, created_at: record.created_at, deleted: record.deleted?)
        end
      end

      def create_history(changed_by:, created_at:, value: nil, deleted: false)
        history_attributes = {value: value, deleted: deleted, changed_by: changed_by, created_at: created_at}
        if persisted?
          history_items.create!(history_attributes)
        else
          history_items.build(history_attributes)
        end
      end

      protected

      def redact_history!
        history_items.update_all(value: nil)
      end
    end
  end
end
