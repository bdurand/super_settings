# frozen_string_literal: true

module SuperSettings
  # Model for each item in a setting's history. When a setting is changed, the system
  # will track the value it is changed to, who it was changed by, and when.
  class HistoryItem
    include Attributes

    attr_accessor :key, :value, :changed_by, :created_at
    attr_writer :deleted

    def initialize(*)
      @deleted = false
      super
    end

    def deleted?
      !!@deleted
    end

    # The display value for the changed_by attribute. This method can be overridden
    # in the configuration by calling `model.define_changed_by_display` with the block to use
    # to get the display value for the changed_by attribute. The default value is
    # the changed_by attribute itself.
    #
    # @return [String, nil]
    def changed_by_display
      return changed_by if changed_by.nil?

      display_proc = SuperSettings.configuration.model.changed_by_display
      if display_proc && !changed_by.nil?
        display_proc.call(changed_by) || changed_by
      else
        changed_by
      end
    end
  end
end
