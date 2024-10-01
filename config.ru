# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= "Gemfile"
require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

require "dotenv/load"

require_relative "lib/super_settings"

class TestApplication < SuperSettings::RackApplication
  def current_user(request)
    "John Doe"
  end
end

SuperSettings.configuration.controller.color_scheme = ENV.fetch("COLOR_SCHEME", "light")

app = TestApplication.new
options = Rackup::Server::Options.new.parse!(ARGV)

storage = ENV.fetch("SUPER_SETTINGS_STORAGE", "redis")
if storage.match?(/\Aredis/i)
  require "redis"
  redis_url = (storage.include?(":") ? storage : ENV["REDIS_URL"])
  SuperSettings::Setting.storage = SuperSettings::Storage::RedisStorage
  SuperSettings::Storage::RedisStorage.redis = Redis.new(url: redis_url)
elsif storage.match?(/\Ahttp(s?):/i)
  SuperSettings::Setting.storage = SuperSettings::Storage::HttpStorage
  SuperSettings::Storage::HttpStorage.base_url = storage
else
  warn "SUPER_SETTINGS_STORAGE must be set to 'redis' or a URL."
  exit 1
end

Rackup::Server.start(options.merge(app: app))
