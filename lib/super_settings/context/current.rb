# frozen_string_literal: true

module SuperSettings
  module Context
    # Current context for maintaining consistent setting values and random numbers
    # within a specific execution context.
    class Current
      def initialize
        @context = {}
        @seed = nil
      end

      # Check if the context includes a specific key.
      #
      # @param key [String] the key to check
      # @return [Boolean] true if the key exists in the context
      def include?(key)
        @context.include?(key)
      end

      # Get a value from the context.
      #
      # @param key [String] the key to retrieve
      # @return [Object] the value associated with the key
      def [](key)
        @context[key]
      end

      # Set a value in the context.
      #
      # @param key [String] the key to set
      # @param value [Object] the value to store
      # @return [Object] the stored value
      def []=(key, value)
        @context[key] = value
      end

      # Delete a value from the context.
      #
      # @param key [String] the key to delete
      # @return [Object] the deleted value
      def delete(key)
        @context.delete(key)
      end

      # Generate a consistent random number for this context.
      #
      # @param max [Integer, Float, Range] the maximum value or range
      # @return [Integer, Float] the random number
      def rand(max = nil)
        @seed ||= Random.new_seed
        Random.new(@seed).rand(max || 1.0)
      end
    end
  end
end
