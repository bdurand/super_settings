# frozen_string_literal: true

module SuperSettings
  # Model for each item in a setting's history. When a setting is changed, the system
  # will track the value it is changed to, who it was changed by, and when.
  class HistoryItem
    include Attributes

    attr_accessor :key, :value, :changed_by, :created_at
    attr_writer :deleted

    def deleted?
      # Stupid strict mode...
      !!(defined?(@deleted) && @deleted)
    end

    # The method could be overriden to change how the changed_by attribute is displayed.
    # For instance, you could store a user id in the changed_by column and add an association
    # on this model.
    #
    # @example
    #   class SuperSettings::HistoryItem
    #     def changed_by_display
    #       user = User.find_by(id: changed_by) if changed_by
    #       user ? user.name : changed_by
    #     end
    #   end
    #
    # @return [String]
    def changed_by_display
      changed_by
    end
  end
end
