# frozen_string_literal: true

# ActiveRecord implementation of the SuperSettings::Storage model.
module SuperSettings
  # Base class that the models extend from.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end

  module Storage
    class ActiveRecordStorage < ApplicationRecord
      self.table_name = "super_settings"

      include Storage

      class HistoryItem < ApplicationRecord
        self.table_name = "super_settings_histories"
        include History
      end

      has_many :history_items, class_name: "#{name}::HistoryItem", foreign_key: :key, primary_key: :key

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
      end

      def history(limit:, offset: 0)
        history_items.order(id: :desc).limit(limit).offset(offset)
      end

      def create_history(attributes)
        if persisted?
          history_items.create!(attributes)
        else
          history_items.build(attributes)
        end
      end

      protected

      def redact_history!
        history_items.update_all(value: nil)
      end
    end
  end
end
