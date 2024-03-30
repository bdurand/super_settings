# frozen_string_literal: true

module SuperSettings
  module Context
    autoload :RackMiddleware, "context/rack_middleware"
    autoload :SidekiqMiddleware, "context/sidekiq_middleware"
  end
end
