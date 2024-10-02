# frozen_string_literal: true

require "zlib"
require "aws-sdk-s3"

module SuperSettings
  module Storage
    # Storage backend for storing the settings in an S3 object. This should work with any S3-compatible
    # storage service.
    class S3Storage < JSONStorage
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
        attr_accessor :access_key_id, :secret_access_key, :region, :endpoint, :bucket, :object

        def initialize
          @access_key_id ||= ENV.fetch("SUPER_SETTINGS_AWS_ACCESS_KEY_ID", ENV["AWS_ACCESS_KEY_ID"])
          @secret_access_key ||= ENV.fetch("SUPER_SETTINGS_AWS_SECRET_ACCESS_KEY", ENV["AWS_SECRET_ACCESS_KEY"])
          @region ||= ENV.fetch("SUPER_SETTINGS_AWS_REGION", ENV["AWS_REGION"])
          @endpoint ||= ENV.fetch("SUPER_SETTINGS_AWS_ENDPOINT", ENV["AWS_ENDPOINT"])
          @bucket ||= ENV.fetch("SUPER_SETTINGS_S3_BUCKET", ENV["AWS_S3_BUCKET"])
          @object ||= ENV.fetch("SUPER_SETTINGS_S3_OBJECT", "super_settings.json")
          self.url = ENV["SUPER_SETTINGS_S3_URL"] unless ENV["SUPER_SETTINGS_S3_URL"].to_s.empty?
        end

        def url=(url)
          return if url.to_s.empty?

          uri = URI.parse(url)
          raise ArgumentError, "Invalid S3 URL" unless uri.scheme == "s3"

          self.access_key_id = uri.user if uri.user
          self.secret_access_key = uri.password if uri.password
          self.region = uri.host if uri.host
          _, bucket, object = uri.path.split("/", 3) if uri.path
          self.bucket = bucket if bucket
          self.object = object if object
        end

        def hash
          [self.class, access_key_id, secret_access_key, region, endpoint, bucket, object].hash
        end
      end

      @bucket = nil
      @bucket_hash = nil

      class << self
        def last_updated_at
          s3_object.last_modified
        end

        def configuration
          @config ||= Configuration.new
        end

        def s3_object
          bucket.object(configuration.object)
        end

        def destroy_all
          s3_object.delete
        end

        protected

        def default_load_asynchronous?
          true
        end

        def json_payload
          object = s3_object
          return nil unless object.exists?

          json = s3_object.get.body.read
          json = Zlib.gunzip(json) if object.content_encoding == "gzip"
          json
        end

        def save_json(json)
          compressed_json = Zlib.gzip(json)
          s3_object.put(body: compressed_json, content_encoding: "gzip")
        end

        private

        def bucket
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
      end
    end
  end
end
