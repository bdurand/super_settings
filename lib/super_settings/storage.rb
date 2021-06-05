# frozen_string_literal: true

require_relative "storage/history"

module SuperSettings
  module Storage
    extend ActiveSupport::Concern

    class RecordInvalid < StandardError
    end

    module ClassMethods
      # Storage classes must implent this method to return all settings included deleted ones.
      # @return [Array<SuperSetting::Setting::Storage>]
      def all_settings
        raise NotImplementedError
      end

      # Return all non-deleted settings.
      # @return [Array<SuperSetting::Setting::Storage>]
      def active_settings
        all_settings.reject(&:deleted?)
      end

      # Storage classes must implement this method to return all settings updates since the
      # specified timestamp.
      # @return [Array<SuperSetting::Setting::Storage>]
      def updated_since(timestamp)
        raise NotImplementedError
      end

      # Storage classes must implement this method to return a settings by it's key.
      # @return [SuperSetting::Setting::Storage]
      def find_by_key(key)
        raise NotImplementedError
      end

      # Storage classes must implement this method to return most recent time that any
      # setting was updated.
      # @return [Time]
      def last_updated_at
        raise NotImplementedError
      end

      # Storage classes can override this method to indicate they are not fully set up yet
      # (i.e. if there is a database table that neeeds to be created, etc.).
      # @return [Boolean]
      def ready?
        true
      end
    end

    # Return array of history items reflecting changes made to the setting over time. Items
    # should be returned in reverse chronological order so that the most recent changes are first.
    # @return [Array<SuperSettings::History>]
    def history(limit:, offset: 0)
      # Must be implemented by a concrete class.
      raise NotImplementedError
    end

    protected

    # Remove the value stored on history records if the setting is changed to a secret since
    # these are not stored encrypted in the database. Implementing classes must redefine this
    # method.
    def redact_history!
      raise NotImplementedError
    end
  end
end

require_relative "storage/redis_storage"
if ActiveSupport.respond_to?(:on_load)
  ActiveSupport.on_load(:active_record) do
    require_relative "storage/active_record_storage"
  end
end
