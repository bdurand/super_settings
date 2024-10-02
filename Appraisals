# frozen_string_literal: true

appraise "rails_latest" do
  gem "sqlite3", "~> 1.4.0"
  gem "puma", "~> 6.0"
  remove_gem "rackup"
end

appraise "rails_7.2" do
  gem "rails", "~> 7.2"
  gem "rspec-rails", "~> 6.0"
  gem "sqlite3", "~> 1.4.0"
  gem "puma", "~> 6.0"
  remove_gem "rackup"
end

appraise "rails_7.1" do
  gem "rails", "~> 7.1.0"
  gem "rspec-rails", "~> 6.0"
  gem "sqlite3", "~> 1.4.0"
  gem "puma", "~> 6.0"
  remove_gem "rackup"
end

appraise "rails_7.0" do
  gem "rails", "~> 7.0.0"
  gem "rspec-rails", "~> 6.0"
  gem "sqlite3", "~> 1.4.0"
  gem "puma", "~> 5.6"
  remove_gem "rackup"
end

appraise "rails_6.1" do
  gem "rails", "~> 6.1.0"
  gem "rspec-rails", "~> 6.0"
  gem "sqlite3", "~> 1.4.0"
  gem "puma", "~> 5.6"
  remove_gem "rackup"
end

appraise "rails_6.0" do
  gem "rails", "~> 6.0.0"
  gem "rspec-rails", "~> 5.1"
  gem "sqlite3", "~> 1.4.0"
  gem "puma", "~> 5.6"
  remove_gem "rackup"
end

appraise "rails_5.2" do
  gem "rails", "~> 5.2.0"
  gem "rspec-rails", "~> 5.1"
  gem "sqlite3", "~> 1.3.0"
  gem "puma", "~> 5.6"
  gem "redis", "~> 4.0"
  remove_gem "rackup"
end

appraise "no_extensions" do
  remove_gem "rails"
  remove_gem "rspec-rails"
  remove_gem "redis"
  remove_gem "connection_pool"
  remove_gem "aws-sdk-s3"
  remove_gem "mongo"
end
