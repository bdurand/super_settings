require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)
require_relative "../../../lib/super_settings"

module Dummy
  class Application < Rails::Application
    if Rails.version.to_f < 5
      config.active_record.raise_in_transactional_callbacks = true
    end
  end
end
