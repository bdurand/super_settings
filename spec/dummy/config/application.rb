require_relative "boot"

require "dotenv/load"

require "rails/all"

Bundler.require(*Rails.groups)
require_relative "../../../lib/super_settings"

module Dummy
  class Application < Rails::Application
  end
end
