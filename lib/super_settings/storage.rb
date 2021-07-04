# frozen_string_literal: true

module SuperSettings
  # Abstraction over how a setting is stored and retrieved from the storage engine. Models
  # must implement the methods module in this module that raise `NotImplementedError`.
  module Storage
    class RecordInvalid < StandardError
    end

    def self.included(base)
      base.extend(ClassMethods)
      base.include(Attributes) unless base.instance_methods.include?(:attributes=)
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

      # Implementing classes can override this method to setup a thread safe connection within a block.
      def with_connection(&block)
        yield
      end

      # Implementing classes can override this method to wrap an operation in an atomic transaction.
      def with_transaction(&block)
        yield
      end
    end

    # @return [String] the key for the setting
    def key
      raise NotImplementedError
    end

    # Set the key for the setting.
    # @param val [String]
    # @return [void]
    def key=(val)
      raise NotImplementedError
    end

    # @return [String] the raw value for the setting before it is type cast.
    def raw_value
      raise NotImplementedError
    end

    # Set the raw value for the setting.
    # @param val [String]
    # @return [void]
    def raw_value=(val)
      raise NotImplementedError
    end

    # @return [String] the value type for the setting
    def value_type
      raise NotImplementedError
    end

    # Set the value type for the setting.
    # @param val [String] one of string, integer, float, boolean, datetime, array, or secret
    # @return [void]
    def value_type=(val)
      raise NotImplementedError
    end

    # @return [String] the description for the setting
    def description
      raise NotImplementedError
    end

    # Set the description for the setting.
    # @param val [String]
    # @return [void]
    def description=(val)
      raise NotImplementedError
    end

    # @return [Boolean] true if the setting is deleted
    def deleted?
      raise NotImplementedError
    end

    # Set the deleted flag for the setting.
    # @param val [Boolean]
    # @return [void]
    def deleted=(val)
      raise NotImplementedError
    end

    # @return [Time] the time the setting was last updated
    def updated_at
      raise NotImplementedError
    end

    # Set the last updated time for the setting.
    # @param val [Time]
    # @return [void]
    def updated_at=(val)
      raise NotImplementedError
    end

    # @return [Time] the time the setting was created
    def created_at
      raise NotImplementedError
    end

    # Set the created time for the setting.
    # @param val [Time]
    # @return [void]
    def created_at=(val)
      raise NotImplementedError
    end

    # Return array of history items reflecting changes made to the setting over time. Items
    # should be returned in reverse chronological order so that the most recent changes are first.
    # @return [Array<SuperSettings::History>]
    def history(limit: nil, offset: 0)
      raise NotImplementedError
    end

    # Create a history item for the setting
    def create_history(changed_by:, created_at:, value: nil, deleted: false)
      raise NotImplementedError
    end

    # Persist the record to storage.
    # @return [void]
    def store!
      raise NotImplementedError
    end

    # @return [Boolean] true if the record has been stored.
    def stored?
      raise NotImplementedError
    end

    def ==(other)
      other.is_a?(self.class) && other.key == key
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

require_relative "storage/http_storage"
require_relative "storage/redis_storage"
if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
  ActiveSupport.on_load(:active_record) do
    require_relative "storage/active_record_storage"
  end
end
