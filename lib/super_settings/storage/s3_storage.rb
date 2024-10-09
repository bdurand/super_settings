# frozen_string_literal: true

require "aws-sdk-s3"

module SuperSettings
  module Storage
    # Storage backend for storing the settings in an S3 object. This should work with any S3-compatible
    # storage service.
    class S3Storage < JSONStorage
      SETTINGS_FILE = "settings.json"
      HISTORY_FILE_SUFFIX = ".history.json"
      DEFAULT_PATH = "super_settings"

      # Configuration for the S3 storage backend.
      #
      # * access_key_id - The AWS access key ID. Defaults to the SUPER_SETTINGS_AWS_ACCESS_KEY_ID
      #   or AWS_ACCESS_KEY_ID environment variable or whatever is set in the `Aws.config` object.
      # * secret_access_key - The AWS secret access key. Defaults to the SUPER_SETTINGS_AWS_SECRET_ACCESS_KEY
      #  or AWS_SECRET_ACCESS_KEY environment variable or whatever is set in the `Aws.config` object.
      # * region - The AWS region. Defaults to the SUPER_SETTINGS_AWS_REGION or AWS_REGION environment variable.
      #   This is required for AWS S3 but may be optional for S3-compatible services.
      # * endpoint - The S3 endpoint URL. This is optional and should only be used for S3-compatible services.
      #   Defaults to the SUPER_SETTINGS_AWS_ENDPOINT or AWS_ENDPOINT environment variable.
      # * bucket - The S3 bucket name. Defaults to the SUPER_SETTINGS_S3_BUCKET or AWS_S3_BUCKET
      #   environment variable.
      # * object - The S3 object key. Defaults to "super_settings.json.gz" or the value set in the
      #   SUPER_SETTINGS_S3_OBJECT environment variable.
      #
      # You can also specify the configuration using a URL in the format using the SUPER_SETTINGS_S3_URL
      # environment variable. The URL should be in the format:
      #
      # ```
      #   s3://access_key_id:secret_access_key@region/bucket/object
      # ```
      class Configuration
        attr_accessor :access_key_id, :secret_access_key, :region, :endpoint, :bucket
        attr_reader :path

        def initialize
          @access_key_id ||= ENV.fetch("SUPER_SETTINGS_AWS_ACCESS_KEY_ID", ENV["AWS_ACCESS_KEY_ID"])
          @secret_access_key ||= ENV.fetch("SUPER_SETTINGS_AWS_SECRET_ACCESS_KEY", ENV["AWS_SECRET_ACCESS_KEY"])
          @region ||= ENV.fetch("SUPER_SETTINGS_AWS_REGION", ENV["AWS_REGION"])
          @endpoint ||= ENV.fetch("SUPER_SETTINGS_AWS_ENDPOINT", ENV["AWS_ENDPOINT"])
          @bucket ||= ENV.fetch("SUPER_SETTINGS_S3_BUCKET", ENV["AWS_S3_BUCKET"])
          @path ||= ENV.fetch("SUPER_SETTINGS_S3_OBJECT", DEFAULT_PATH)
          self.url = ENV["SUPER_SETTINGS_S3_URL"] unless ENV["SUPER_SETTINGS_S3_URL"].to_s.empty?
        end

        def url=(url)
          return if url.to_s.empty?

          uri = URI.parse(url)
          raise ArgumentError, "Invalid S3 URL" unless uri.scheme == "s3"

          self.access_key_id = uri.user if uri.user
          self.secret_access_key = uri.password if uri.password
          self.region = uri.host if uri.host
          _, bucket, path = uri.path.split("/", 3) if uri.path
          self.bucket = bucket if bucket
          self.path = path if path
        end

        def path=(value)
          @path = "#{value}.chomp('/')/"
        end

        def hash
          [self.class, access_key_id, secret_access_key, region, endpoint, bucket, path].hash
        end
      end

      @bucket = nil
      @bucket_hash = nil

      class << self
        def last_updated_at
          all.collect(&:updated_at).compact.max
        end

        def configuration
          @config ||= Configuration.new
        end

        def destroy_all
          s3_bucket.objects(prefix: configuration.path).each do |object|
            if object.key == file_path(SETTINGS_FILE) || object.key.end_with?(HISTORY_FILE_SUFFIX)
              object.delete
            end
          end
        end

        protected

        def default_load_asynchronous?
          true
        end

        def settings_json_payload
          object = settings_object
          return nil unless object.exists?

          object.get.body.read
        end

        def save_settings_json(json)
          object = settings_object
          object.put(body: json)
        end

        def save_history_json(key, json)
          object = history_object(key)
          object.put(body: json)
        end

        private

        def s3_bucket
          if configuration.hash != @bucket_hash
            @bucket_hash = configuration.hash
            options = {
              endpoint: configuration.endpoint,
              access_key_id: configuration.access_key_id,
              secret_access_key: configuration.secret_access_key,
              region: configuration.region
            }
            options[:force_path_style] = true if configuration.endpoint
            options.compact!

            @bucket = Aws::S3::Resource.new(options).bucket(configuration.bucket)
          end
          @bucket
        end

        def s3_object(filename)
          s3_bucket.object(file_path(filename))
        end

        def file_path(filename)
          "#{configuration.path}#{filename}"
        end

        def settings_object
          s3_object(SETTINGS_FILE)
        end

        def history_object(key)
          s3_object("#{key}#{HISTORY_FILE_SUFFIX}")
        end

        def history_json(key)
          object = history_object(key)
          return nil unless object.exists?

          object.get.body.read
        end
      end

      protected

      def fetch_history_json
        self.class.send(:history_json, key)
      end
    end
  end
end
