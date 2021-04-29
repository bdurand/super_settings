# frozen_string_literal: true

require_relative "application_record"

module SuperSettings
  class Setting < ApplicationRecord
    LAST_UPDATED_CACHE_KEY = "SuperSettings.last_updated_at"

    STRING = "string"
    INTEGER = "integer"
    FLOAT = "float"
    BOOLEAN = "boolean"
    DATETIME = "datetime"
    ARRAY = "array"
    SECRET = "secret"

    VALUE_TYPES = [STRING, INTEGER, FLOAT, BOOLEAN, DATETIME, ARRAY, SECRET].freeze

    ARRAY_DELIMITER = /[\n\r]+/.freeze

    SALT = "0c54a781"
    private_constant :SALT

    # Error thrown when the secret is invalid
    class InvalidSecretError < StandardError
      def initialize
        super("Cannot decrypt. Invalid secret provided.")
      end
    end

    self.table_name = "super_settings"

    attr_accessor :changed_by

    default_scope -> { where(deleted: false) }

    scope :with_deleted, -> { unscope(where: :deleted) }

    # Scope to select just the date needed to load the setting values.
    scope :runtime_data, -> { select([:id, :key, :value_type, :raw_value, :deleted, :last_used_at]) }

    has_many :histories, class_name: "History", foreign_key: :key, primary_key: :key

    validates :value_type, inclusion: {in: VALUE_TYPES}
    validates :key, presence: true, length: {maximum: 190}, uniqueness: true
    validates :raw_value, length: {maximum: 4096}
    validate { validate_parsable_value(raw_value) }

    after_find :clear_changed_by
    after_save :clear_changed_by

    before_save do
      self.raw_value = serialize(raw_value) unless array?
      if secret? && raw_value && !SecretKeys::Encryptor.encrypted?(raw_value)
        self.raw_value = self.class.encrypt(raw_value)
      end
      record_value_change
    end

    after_commit do
      self.class.cache&.delete(LAST_UPDATED_CACHE_KEY)
    end

    class << self
      attr_accessor :cache

      def last_updated_at
        fetch_from_cache(LAST_UPDATED_CACHE_KEY) do
          with_deleted.maximum(:updated_at)
        end
      end

      # Set the secret key used for encrypting secret values. If this is not set,
      # the value will be loaded from the `SUPER_SETTINGS_SECRET` environment
      # variable. If that value is not set, arguments will not be encrypted.
      #
      # You can set multiple secrets by passing an array if you need to roll your secrets.
      # The left most value in the array will be used as the encryption secret, but
      # all the values will be tried when decrypting. That way if you have existing keys
      # that were encrypted with a different secret, you can still make it available
      # when decrypting. If you are using the environment variable, separate the keys
      # with spaces.
      #
      # @param [String] value One or more secrets to use for encrypting arguments.
      # @return [void]
      def secret=(value)
        @encryptors = make_encryptors(value)
      end

      def encrypt(value)
        return nil if value.blank?
        encryptor = encryptors.first
        return value if encryptor.nil?
        encryptor.encrypt(value)
      end

      def decrypt(value)
        return nil if value.blank?
        return value if encryptors.empty? || encryptors == [nil]
        encryptors.each do |encryptor|
          begin
            return encryptor.decrypt(value) if encryptor
          rescue OpenSSL::Cipher::CipherError
            # Not the right key, try the next one
          end
        end
        raise InvalidSecretError
      end

      private

      def encryptors
        if !defined?(@encryptors) || @encryptors.empty?
          @encryptors = make_encryptors(ENV["SUPER_SETTINGS_SECRET"].to_s.split)
        end
        @encryptors
      end

      def make_encryptors(secrets)
        Array(secrets).map { |val| val.nil? ? nil : SecretKeys::Encryptor.from_password(val, SALT) }
      end

      def fetch_from_cache(key, &block)
        if cache
          cache.fetch(key, &block)
        else
          block.call
        end
      end
    end

    def value
      if deleted?
        nil
      else
        coerce(raw_value)
      end
    end

    def value=(val)
      self.raw_value = (val.is_a?(Array) ? val.join("\n") : val)
    end

    def string?
      value_type == STRING
    end

    def integer?
      value_type == INTEGER
    end

    def float?
      value_type == FLOAT
    end

    def boolean?
      value_type == BOOLEAN
    end

    def datetime?
      value_type == DATETIME
    end

    def array?
      value_type == ARRAY
    end

    def secret?
      value_type == SECRET
    end

    def encrypted?
      secret? && SecretKeys::Encryptor.encrypted?(raw_value)
    end

    def destroy!
      update!(deleted: true)
    end

    # Serialize to a hash that is used for rendering JSON responses.
    def as_json(options = nil)
      {
        id: id,
        key: key,
        value: value,
        value_type: value_type,
        description: description,
        created_at: created_at,
        updated_at: updated_at
      }
    end

    private

    def coerce(value)
      return nil if value.blank?

      case value_type
      when STRING
        value.freeze
      when INTEGER
        Integer(value)
      when FLOAT
        Float(value)
      when BOOLEAN
        BooleanParser.cast(value)
      when DATETIME
        Time.parse(value).in_time_zone(Time.zone).freeze
      when ARRAY
        if value.is_a?(String)
          value.split(ARRAY_DELIMITER).map(&:freeze).freeze
        else
          Array(value).reject(&:blank?).map { |v| v.to_s.freeze }.freeze
        end
      when SECRET
        begin
          self.class.decrypt(value).freeze
        rescue InvalidSecretError
          nil
        end
      else
        value.freeze
      end
    rescue ArgumentError
      nil
    end

    def serialize(value)
      if value.blank?
        nil
      elsif value.is_a?(Time) || value.is_a?(DateTime)
        value.utc.iso8601(6)
      else
        coerce(value.to_s)
      end
    end

    def validate_parsable_value(value)
      if value.present? && coerce(value).nil?
        if integer?
          errors.add(:value, :not_an_integer)
        elsif float?
          errors.add(:value, :not_a_number)
        elsif datetime?
          errors.add(:value, :invalid)
        end
      end
    end

    def record_value_change
      return unless raw_value_changed? || deleted_changed? || key_changed?
      recorded_value = (deleted? || secret? ? nil : raw_value)
      history_attributes = {value: recorded_value, deleted: deleted, changed_by: changed_by}
      if new_record?
        histories.build(history_attributes)
      else
        histories.create!(history_attributes)
      end
    end

    def clear_changed_by
      self.changed_by = nil
    end
  end
end
