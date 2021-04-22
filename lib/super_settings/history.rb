# frozen_string_literal: true

require_relative "application_record"

module SuperSettings
  class History < ApplicationRecord
    self.table_name = "super_settings_histories"

    belongs_to :setting, class_name: "SuperSettings::Setting", foreign_key: :key, primary_key: :key

    before_validation do
      self.changed_by = changed_by.to_s[0, 150] if changed_by.present?
    end

    def changed_by_display
      changed_by
    end

    def as_json(options = nil)
      {
        key: key,
        value: value,
        changed_by: changed_by,
        created_at: created_at
      }
    end
  end
end
