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
    class_name = File.basename(path).sub(/\.rb/, "").split("_", 2).last.camelcase
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

class TestMiddleware < SuperSettings::RackMiddleware
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

Capybara.app = TestMiddleware.new(lambda { |env| [204, {}, [""]] })
Capybara.javascript_driver = :cuprite
WebMock.disable_net_connect!(allow_localhost: true)

redis = Redis.new(url: ENV["TEST_REDIS_URL"]) if ENV["TEST_REDIS_URL"]
if redis
  SuperSettings::Storage::RedisStorage.redis = redis
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

I18n.locale = :en if defined?(I18n)

# Needed to handle specs for Rails 4.2.
def request_params(params)
  if defined?(Rails) && Rails.version.to_f < 5.0
    params
  else
    {params: params}
  end
end
