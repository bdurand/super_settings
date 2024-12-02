# frozen_string_literal: true

module SuperSettings
  module Storage
    # No-op implementation of the SuperSettings::Storage model. You can use this model if there
    # is no other storage engine available. It can be useful for situations where the normal
    # storage engine is not available, such as in a continious integration environment.
    class NullStorage
      # :nocov:

      include Storage

      attr_accessor :key, :raw_value, :description, :value_type, :updated_at, :created_at, :changed_by

      class << self
        attr_reader :settings

        def history(key)
          []
        end

        def destroy_all
        end

        def all
          []
        end

        def updated_since(time)
          []
        end

        def find_by_key(key)
          nil
        end

        def last_updated_at
          nil
        end

        def create_history(key:, changed_by:, created_at:, value: nil, deleted: false)
          nil
        end

        def load_asynchronous?
          false
        end
      end

      def history(limit: nil, offset: 0)
        []
      end

      def save!
        true
      end

      def deleted=(value)
      end

      def deleted?
        false
      end

      def persisted?
        false
      end

      # :nocov:
    end
  end
end
