# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

begin
  require "simplecov"
  SimpleCov.start do
    add_filter ["/spec/", "/app/", "/config/", "/db/"]
  end
rescue LoadError
end

ENV["RAILS_ENV"] = "test"
db_file = File.expand_path("dummy/db/test.sqlite3", __dir__)
File.unlink(db_file) if File.exist?(db_file)

Bundler.require(:default, :test)

require "dotenv/load"

extensions = []

require_relative "../lib/super_settings/storage/test_storage"
SuperSettings::Setting.storage = SuperSettings::Storage::TestStorage

if defined?(Rails) && !SuperSettings::Coerce.boolean(ENV["SKIP_RAILS"])
  extensions << "rails"

  require_relative "../lib/super_settings/engine"

  require File.expand_path("dummy/config/environment", __dir__)

  Dir.glob(File.expand_path("../db/migrate/*.rb", __dir__)).sort.each do |path|
    require(path)
    class_name = File.basename(path).sub(".rb", "").split("_", 2).last.camelcase
    class_name.constantize.migrate(:up)
  end
  SuperSettings::Storage::ActiveRecordStorage::ApplicationRecord.connection.schema_cache.clear!
  SuperSettings::Storage::ActiveRecordStorage::Model.reset_column_information
  SuperSettings::Storage::ActiveRecordStorage::HistoryModel.reset_column_information

  require "rspec-rails"
  require "rspec/rails"
end

if defined?(Redis)
  if ENV["TEST_REDIS_URL"] == "default"
    ENV["TEST_REDIS_URL"] = "redis://localhost:#{ENV.fetch("REDIS_PORT", "6379")}/1"
  end
  if ENV["TEST_REDIS_URL"]
    extensions << "redis"
    redis = Redis.new(url: ENV["TEST_REDIS_URL"])
    if redis
      SuperSettings::Storage::RedisStorage.redis = redis
    end
  end
else
  ENV["TEST_REDIS_URL"] = nil
end

if defined?(Aws)
  if ENV["TEST_S3_URL"] == "default"
    storage_url = "s3://accesskey:secretkey@region-1/settings/test_settings.json"
    endpoint = "http://localhost:#{ENV.fetch("S3_PORT", "9000")}"
    config = SuperSettings::Storage::S3Storage.configuration
    config.endpoint = endpoint
    config.url = storage_url
    bucket = SuperSettings::Storage::S3Storage.send(:bucket)
    bucket.create unless bucket.exists?
    object = SuperSettings::Storage::S3Storage.s3_object
    object.delete if object.exists?
    extensions << "s3"
  elsif ENV["TEST_S3_URL"]
    SuperSettings::Storage::S3Storage.configuration.storage_url = ENV["TEST_S3_URL"]
    extensions << "s3"
  end
else
  ENV["TEST_S3_URL"] = nil
end

if defined?(Mongo)
  if ENV["TEST_MONGODB_URL"] == "default"
    ENV["TEST_MONGODB_URL"] = "mongodb://localhost:#{ENV.fetch("MONGODB_PORT", "27017")}/super_settings_test"
  end
  if ENV["TEST_MONGODB_URL"]
    SuperSettings::Storage::MongoDBStorage.url = ENV["TEST_MONGODB_URL"]
    extensions << "mongodb"
  end
else
  ENV["TEST_MONGODB_URL"] = nil
end

puts "Testing with extensions: #{extensions.join(", ")}" unless extensions.empty?

require "webmock/rspec"
require "capybara/rspec"
require "capybara/cuprite"
require "nokogiri"

class TestMiddleware < SuperSettings::RackApplication
  protected

  def authenticated?(user)
    true
  end

  def current_user(request)
    "John Doe"
  end

  def changed_by(user)
    user
  end
end

Capybara.app = SuperSettings::RackApplication.new(lambda { |env| [204, {}, [""]] }) do
  def current_user(request)
    "John Doe"
  end

  def changed_by(user)
    user
  end
end

Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1024, 800],
    browser_options: {"no-sandbox": nil},
    headless: true,
    timeout: 30
  )
end

Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.default_max_wait_time = 5

WebMock.disable_net_connect!(allow_localhost: true)

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    if defined?(Rails)
      config.render_views = true
    end

    if SuperSettings::Setting.storage.respond_to?(:destroy_all)
      SuperSettings::Setting.storage.destroy_all
    end

    SuperSettings.clear_cache

    Rails.cache.clear if defined?(Rails.cache) && Rails.cache.respond_to?(:clear)
  end

  config.order = :random
end

SuperSettings::Storage::HttpStorage.base_url = "https://example.com/super_settings"

class FakeLogger
  @instance = nil

  class << self
    def instance
      @instance ||= new
    end
  end

  attr_reader :messages

  def initialize
    @messages = []
  end
end

SuperSettings::Setting.after_save do |setting|
  FakeLogger.instance.messages << {key: setting.changes["key"], value: setting.changes["raw_value"]}
end

I18n.locale = :en if defined?(I18n)

def post_json(action, params)
  request.headers["content-type"] = "application/json"
  if defined?(Rails) && Rails.version.to_f < 5.0
    post action, params, format: :json
  else
    post action, body: params.to_json, format: :json
  end
end
