# frozen_string_literal: true

require_relative "application_record"

module SuperSettings
  # Model to keep track of changes to the settings.
  class History < ApplicationRecord
    self.table_name = "super_settings_histories"

    belongs_to :setting, class_name: "Setting", foreign_key: :key, primary_key: :key

    # Since these models are created automatically on a callback, ensure that the data will
    # fit into the database columns since we can't handle any validation errors.
    before_validation do
      self.changed_by = changed_by.to_s[0, 150] if changed_by.present?
    end

    # The method could be overriden to change how the changed_by attribute is displayed.
    # For instance, you could store a user id in the changed_by column and add an association
    # on this model `belongs_to :user, class_name: "User", foreign_key: :changed_by` and then
    # define this method as `user.name`.
    # @return [String]
    def changed_by_display
      changed_by
    end

    # Serialize to a hash that is used for rendering JSON responses.
    # @return [Hash]
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
