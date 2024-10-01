# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

# Rails is not an explicit dependency but if we are running with it for tests we need to make
# sure ActiveSupport is loaded before the SuperSettings gem
begin
  require "active_support/all"
rescue LoadError
end

begin
  require "simplecov"
  SimpleCov.start do
    add_filter ["/spec/", "/app/", "/config/", "/db/"]
  end
rescue LoadError
end

Bundler.require(:default, :test)

require_relative "../lib/super_settings/storage/test_storage"

if defined?(Rails)
  ENV["RAILS_ENV"] ||= "test"

  db_file = File.expand_path("dummy/db/test.sqlite3", __dir__)
  File.unlink(db_file) if File.exist?(db_file)

  require File.expand_path("dummy/config/environment", __dir__)

  require "rspec-rails"
  require "rspec/rails"

  Dir.glob(File.expand_path("../db/migrate/*.rb", __dir__)).sort.each do |path|
    require(path)
    class_name = File.basename(path).sub(".rb", "").split("_", 2).last.camelcase
    class_name.constantize.migrate(:up)
  end
  SuperSettings::Storage::ActiveRecordStorage::Model.reset_column_information

  SuperSettings::Setting.storage = SuperSettings::Storage::ActiveRecordStorage
else
  require "dotenv/load"
  SuperSettings::Setting.storage = SuperSettings::Storage::TestStorage
end

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

if ENV["TEST_REDIS_URL"] == "default"
  ENV["TEST_REDIS_URL"] = "redis://localhost:#{ENV.fetch("REDIS_PORT", "6379")}/1"
end
if ENV["TEST_REDIS_URL"]
  redis = Redis.new(url: ENV["TEST_REDIS_URL"])
  if redis
    SuperSettings::Storage::RedisStorage.redis = redis
  end
end

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
elsif ENV["TEST_S3_URL"]
  SuperSettings::Storage::S3Storage.configuration.storage_url = ENV["TEST_S3_URL"]
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    if defined?(Rails)
      SuperSettings::Storage::ActiveRecordStorage::Model.destroy_all
      SuperSettings::Storage::ActiveRecordStorage::HistoryModel.destroy_all
      config.render_views = true
    end

    if redis
      SuperSettings::Storage::RedisStorage.destroy_all
    end

    SuperSettings::Storage::TestStorage.clear

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
