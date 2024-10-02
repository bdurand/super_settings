# frozen_string_literal: true

module SuperSettings
  # Abstraction over how a setting is stored and retrieved from the storage engine. Models
  # must implement the methods module in this module that raise NotImplementedError.
  module Storage
    autoload :StorageAttributes, File.join(__dir__, "storage/storage_attributes")
    autoload :HistoryAttributes, File.join(__dir__, "storage/history_attributes")
    autoload :Transaction, File.join(__dir__, "storage/transaction")
    autoload :ActiveRecordStorage, File.join(__dir__, "storage/active_record_storage")
    autoload :HttpStorage, File.join(__dir__, "storage/http_storage")
    autoload :RedisStorage, File.join(__dir__, "storage/redis_storage")
    autoload :JSONStorage, File.join(__dir__, "storage/json_storage")
    autoload :S3Storage, File.join(__dir__, "storage/s3_storage")
    autoload :MongoDBStorage, File.join(__dir__, "storage/mongodb_storage")

    def self.included(base)
      base.extend(ClassMethods)
      base.include(Attributes) unless base.instance_methods.include?(:attributes=)

      base.instance_variable_set(:@load_asynchronous, nil)
    end

    module ClassMethods
      # Storage classes must implent this method to return all settings included deleted ones.
      #
      # @return [Array<SuperSetting::Setting::Storage>]
      def all
        # :nocov:
        raise NotImplementedError
        # :nocov:
      end

      # Return all non-deleted settings.
      #
      # @return [Array<SuperSetting::Setting::Storage>]
      def active
        all.reject(&:deleted?)
      end

      # Storage classes must implement this method to return all settings updates since the
      # specified timestamp.
      #
      # @return [Array<SuperSetting::Setting::Storage>]
      def updated_since(timestamp)
        # :nocov:
        raise NotImplementedError
        # :nocov:
      end

      # Storage classes must implement this method to return a settings by it's key.
      #
      # @return [SuperSetting::Setting::Storage]
      def find_by_key(key)
        # :nocov:
        raise NotImplementedError
        # :nocov:
      end

      # Storage classes must implement this method to return most recent time that any
      # setting was updated.
      #
      # @return [Time]
      def last_updated_at
        # :nocov:
        raise NotImplementedError
        # :nocov:
      end

      # Implementing classes can override this method to setup a thread safe connection within a block.
      #
      # @return [void]
      def with_connection(&block)
        yield
      end

      # Implementing classes can override this method to wrap an operation in an atomic transaction.
      #
      # @return [void]
      def transaction(&block)
        yield
      end

      # Return true if it's safe to load setting asynchronously in a background thread.
      #
      # @return [Boolean]
      def load_asynchronous?
        !!(@load_asynchronous.nil? ? default_load_asynchronous? : @load_asynchronous)
      end

      # Set to true to force loading setting asynchronously in a background thread.
      attr_writer :load_asynchronous

      protected

      # Implementing classes can override this method to indicate if it is safe to load the
      # setting in a separate thread.
      def default_load_asynchronous?
        false
      end
    end

    # The key for the setting
    #
    # @return [String]
    def key
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the key for the setting.
    #
    # @param val [String]
    # @return [void]
    def key=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # The raw value for the setting before it is type cast.
    #
    # @return [String]
    def raw_value
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the raw value for the setting.
    #
    # @param val [String]
    # @return [void]
    def raw_value=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # The value type for the setting.
    #
    # @return [String]
    def value_type
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the value type for the setting.
    #
    # @param val [String] one of string, integer, float, boolean, datetime, or array
    # @return [void]
    def value_type=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # The description for the setting.
    #
    # @return [String]
    def description
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the description for the setting.
    #
    # @param val [String]
    # @return [void]
    def description=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Return true if the setting marked as deleted.
    #
    # @return [Boolean]
    def deleted?
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the deleted flag for the setting. Settings should not actually be deleted since
    # the record is needed to keep the local cache up to date.
    #
    # @param val [Boolean]
    # @return [void]
    def deleted=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Return the time the setting was last updated
    #
    # @return [Time]
    def updated_at
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the last updated time for the setting.
    #
    # @param val [Time]
    # @return [void]
    def updated_at=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Return the time the setting was created.
    #
    # @return [Time]
    def created_at
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Set the created time for the setting.
    #
    # @param val [Time]
    # @return [void]
    def created_at=(val)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Return array of history items reflecting changes made to the setting over time. Items
    # should be returned in reverse chronological order so that the most recent changes are first.
    #
    # @return [Array<SuperSettings::History>]
    def history(limit: nil, offset: 0)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Create a history item for the setting.
    #
    # @return [void]
    def create_history(changed_by:, created_at:, value: nil, deleted: false)
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Persist the record to storage.
    #
    # @return [void]
    def save!
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    # Return true if the record has been stored.
    # @return [Boolean]
    def persisted?
      # :nocov:
      raise NotImplementedError
      # :nocov:
    end

    def ==(other)
      other.is_a?(self.class) && other.key == key
    end
  end
end

# :nocov:
if defined?(ActiveSupport) && ActiveSupport.respond_to?(:on_load)
  ActiveSupport.on_load(:active_record_base) do
    require_relative "storage/active_record_storage"
  end
end
# :nocov:
