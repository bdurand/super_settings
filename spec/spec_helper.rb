# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('dummy/config/environment', __dir__)
require "rspec-rails"
require "rspec/rails"

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.before do
    SuperSettings::Setting.destroy_all
    SuperSettings.clear_cache
    Rails.cache.clear if defined?(Rails.cache) && Rails.cache.respond_to?(:clear)
  end

  config.order = :random

  config.render_views = true
end

Dir.glob(File.expand_path("../db/migrate/*.rb", __dir__)).each do |path|
  require(path)
  class_name = File.basename(path).sub(/\.rb/, '').split('_', 2).last.camelcase
  class_name.constantize.migrate(:up)
end
SuperSettings::Setting.reset_column_information

I18n.locale = :en
