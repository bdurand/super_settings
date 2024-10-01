# frozen_string_literal: true

module SuperSettings
  module Storage
    # This module provides support for transactions in storage models that don't natively
    # support transactions.
    module Transaction
      def self.included(base)
        base.extend(ClassMethods)
      end

      module ClassMethods
        def transaction(&block)
          if Thread.current[transaction_key]
            yield Thread.current[transaction_key]
          else
            begin
              changes = []
              Thread.current[transaction_key] = changes

              yield(changes)

              if save_all(changes) != false
                changes.each do |object|
                  object.persisted = true if object.respond_to?(:persisted=)
                end
              end
            ensure
              Thread.current[transaction_key] = nil
            end
          end
        end

        def save_all(changes)
          # :nocov:
          raise NotImplementedError
          # :nocov:
        end

        private

        def transaction_key
          "#{name}.transaction"
        end
      end

      def persisted=(value)
        @persisted = Coerce.boolean(value)
      end

      def persisted?
        !!@persisted
      end

      def save!
        self.updated_at ||= Time.now
        self.created_at ||= updated_at

        self.class.transaction do |changes|
          changes << self
        end

        true
      end
    end
  end
end
