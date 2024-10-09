# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= "Gemfile"
require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

require "dotenv/load"

require_relative "lib/super_settings"

class TestApplication < SuperSettings::RackApplication
  def current_user(request)
    ENV.fetch("SUPER_SETTINGS_USER", "John Doe")
  end

  def changed_by(user)
    user
  end
end

SuperSettings.configuration.controller.color_scheme = ENV.fetch("COLOR_SCHEME", "light")

app = TestApplication.new

storage = ENV.fetch("STORAGE", "redis")
if storage == "redis"
  require "redis"
  storage_url = ENV.fetch("REDIS_URL", "redis://localhost:#{ENV.fetch("REDIS_PORT", "6379")}/0")
  SuperSettings::Setting.storage = SuperSettings::Storage::RedisStorage
  SuperSettings::Storage::RedisStorage.redis = Redis.new(url: storage_url)
elsif storage == "http"
  storage_url = ENV.fetch("REST_API_URL", "http://localhost:#{ENV.fetch("RAILS_PORT", "3000")}/settings")
  SuperSettings::Setting.storage = SuperSettings::Storage::HttpStorage
  SuperSettings::Storage::HttpStorage.base_url = storage_url
elsif storage == "s3"
  storage_url = ENV.fetch("S3_URL", nil)
  endpoint = nil
  create_bucket = false

  if storage_url.nil?
    storage_url = "s3://accesskey:secretkey@region-1/settings/settings.json"
    endpoint = "http://localhost:#{ENV.fetch("S3_PORT", "9000")}"
    create_bucket = true
  end

  SuperSettings::Setting.storage = SuperSettings::Storage::S3Storage
  config = SuperSettings::Storage::S3Storage.configuration
  config.endpoint = endpoint
  config.url = storage_url

  if create_bucket
    bucket = SuperSettings::Storage::S3Storage.send(:s3_bucket)
    bucket.create unless bucket.exists?
  end
elsif storage == "mongodb"
  storage_url = ENV.fetch("MONGODB_URL", "mongodb://localhost:#{ENV.fetch("MONGODB_PORT", "27017")}/super_settings")
  SuperSettings::Setting.storage = SuperSettings::Storage::MongoDBStorage
  SuperSettings::Storage::MongoDBStorage.url = storage_url
else
  warn "SUPER_SETTINGS_STORAGE must be set to 'redis', 'http', 's3', or 'mongodb'."
  exit 1
end

run app
