# frozen_string_literal: true

module SuperSettings
  module Storage
    class ActiveRecordStorage
      # Base class that the models extend from.
      class ApplicationRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      class Model < ApplicationRecord
        self.table_name = "super_settings"

        has_many :history_items, class_name: "SuperSettings::Storage::ActiveRecordStorage::HistoryModel", foreign_key: :key, primary_key: :key

        class << self
          # ActiveRecord storage is only available if the connection pool is connected and the table exists.
          def available?
            connection_pool&.connected? && table_exists?
          end
        end
      end

      class HistoryModel < ApplicationRecord
        self.table_name = "super_settings_histories"

        # Since these models are created automatically on a callback, ensure that the data will
        # fit into the database columns since we can't handle any validation errors.
        before_validation do
          self.changed_by = changed_by.to_s[0, 150] if changed_by.present?
        end
      end
    end
  end
end
