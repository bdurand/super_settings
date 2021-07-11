# frozen_string_literal: true

module SuperSettings
  module Encryption
    SALT = "0c54a781"
    private_constant :SALT

    # Error thrown when the secret is invalid
    class InvalidSecretError < StandardError
      def initialize
        super("Cannot decrypt. Invalid secret provided.")
      end
    end

    class << self
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
      # @param value [String] One or more secrets to use for encrypting arguments.
      # @return [void]
      def secret=(value)
        @encryptors = make_encryptors(value)
      end

      # Encrypt a value for use with secret settings.
      # @api private
      def encrypt(value)
        return nil if Coerce.blank?(value)
        encryptor = encryptors.first
        return value if encryptor.nil?
        encryptor.encrypt(value)
      end

      # Decrypt a value for use with secret settings.
      # @api private
      def decrypt(value)
        return nil if Coerce.blank?(value)
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

      # @return [Boolean] true if the value is encrypted in the storage engine.
      def encrypted?(value)
        SecretKeys::Encryptor.encrypted?(value)
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
    end
  end
end
