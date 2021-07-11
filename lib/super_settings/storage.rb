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
      def all
        # :nocov:
        raise NotImplementedError
        # :nocov:
      end

      # Return all non-deleted settings.
      # @return [Array<SuperSetting::Setting::Storage>]
      def active
        all.reject(&:deleted?)
      end

      # Storage classes must implement this method to return all settings updates since the
      # specified timestamp.
      # @return [Array<SuperSetting::Setting::Storage>]
      def updated_since(timestamp)
        # :nocov:
        raise NotImplementedError
        # :nocov:
      end

      # Storage classes must implement this method to return a settings by it's key.
      # @return [SuperSetting::Setting::Storage]
      def find_by_key(key)
        # :nocov:
        raise NotImplementedError
        # :nocov:
      end

      # Storage classes must implement this method to return most recent time that any
      # setting was updated.
      # @return [Time]
      def last_updated_at
        # :nocov:
        raise NotImplementedError
        # :nocov:
      end

      # Implementing classes can override this method to setup a thread safe connection within a block.
      def with_connection(&block)
        yield
      end

      # Implementing classes can override this method to wrap an operation in an atomic transaction.
      def transaction(&block)
        yield
      end
    end

    # @return [String] the key for the setting
    def key
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the key for the setting.
    # @param val [String]
    # @return [void]
    def key=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # @return [String] the raw value for the setting before it is type cast.
    def raw_value
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the raw value for the setting.
    # @param val [String]
    # @return [void]
    def raw_value=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # @return [String] the value type for the setting
    def value_type
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the value type for the setting.
    # @param val [String] one of string, integer, float, boolean, datetime, array, or secret
    # @return [void]
    def value_type=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # @return [String] the description for the setting
    def description
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the description for the setting.
    # @param val [String]
    # @return [void]
    def description=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # @return [Boolean] true if the setting marked as deleted
    def deleted?
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the deleted flag for the setting. Settings should not actually be deleted since
    # the record is needed to keep the local cache up to date.
    # @param val [Boolean]
    # @return [void]
    def deleted=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # @return [Time] the time the setting was last updated
    def updated_at
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the last updated time for the setting.
    # @param val [Time]
    # @return [void]
    def updated_at=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # @return [Time] the time the setting was created
    def created_at
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the created time for the setting.
    # @param val [Time]
    # @return [void]
    def created_at=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Return array of history items reflecting changes made to the setting over time. Items
    # should be returned in reverse chronological order so that the most recent changes are first.
    # @return [Array<SuperSettings::History>]
    def history(limit: nil, offset: 0)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Create a history item for the setting
    def create_history(changed_by:, created_at:, value: nil, deleted: false)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Persist the record to storage.
    # @return [void]
    def save!
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # @return [Boolean] true if the record has been stored.
    def persisted?
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    def ==(other)
      other.is_a?(self.class) && other.key == key
    end

    protected

    # Remove the value stored on history records if the setting is changed to a secret since
    # these are not stored encrypted in the database. Implementing classes must redefine this
    # method.
    def redact_history!
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end
  end
end

# :nocov:
require_relative "storage/http_storage"
require_relative "storage/redis_storage"
if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
  ActiveSupport.on_load(:active_record) do
    require_relative "storage/active_record_storage"
  end
elsif defined?(ActiveRecord::Base)
  require_relative "storage/active_record_storage"
end
# :nocov:
