# frozen_string_literal: true

module SuperSettings
  module Context
    class Current
      def initialize
        @context = {}
        @seed = nil
      end

      def include?(key)
        @context.include?(key)
      end

      def [](key)
        @context[key]
      end

      def []=(key, value)
        @context[key] = value
      end

      def delete(key)
        @context.delete(key)
      end

      def rand(max = nil)
        @seed ||= Random.new_seed
        Random.new(@seed).rand(max || 1.0)
      end
    end
  end
end
