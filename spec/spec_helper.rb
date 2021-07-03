# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

db_file = File.expand_path("dummy/db/test.sqlite3", __dir__)
File.unlink(db_file) if File.exist?(db_file)

require File.expand_path("dummy/config/environment", __dir__)
require "rspec-rails"
require "rspec/rails"
require "dotenv/load"
require "webmock/rspec"

redis = Redis.new(url: ENV["REDIS_URL"])

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    SuperSettings::Storage::ActiveRecordStorage.destroy_all
    SuperSettings::Storage::ActiveRecordStorage::HistoryStorage.destroy_all

    SuperSettings::Storage::RedisStorage.destroy_all

    SuperSettings.clear_cache
    Rails.cache.clear if defined?(Rails.cache) && Rails.cache.respond_to?(:clear)
  end

  config.order = :random

  config.render_views = true
end

Dir.glob(File.expand_path("../db/migrate/*.rb", __dir__)).sort.each do |path|
  require(path)
  class_name = File.basename(path).sub(/\.rb/, "").split("_", 2).last.camelcase
  class_name.constantize.migrate(:up)
end
SuperSettings::Storage::ActiveRecordStorage.reset_column_information

SuperSettings::Storage::RedisStorage.redis = redis

SuperSettings::Storage::HttpStorage.base_url = "https://example.com/settings"

I18n.locale = :en

# Needed to handle specs for Rails 4.2.
def request_params(params)
  if Rails.version.to_f < 5.0
    params
  else
    {params: params}
  end
end
