# frozen_string_literal: true

module SuperSettings
  module Storage
    # Mixing for model to keep track of changes to the settings.
    module HistoryStorage
      # The method could be overriden to change how the changed_by attribute is displayed.
      # For instance, you could store a user id in the changed_by column and add an association
      # on this model `belongs_to :user, class_name: "User", foreign_key: :changed_by` and then
      # define this method as `user.name`.
      # @return [String]
      def changed_by_display
        changed_by
      end
    end
  end
end