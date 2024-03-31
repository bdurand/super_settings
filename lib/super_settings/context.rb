# frozen_string_literal: true

module SuperSettings
  module Context
    autoload :RackMiddleware, File.join(__dir__, "context/rack_middleware")
    autoload :SidekiqMiddleware, File.join(__dir__, "context/sidekiq_middleware")
  end
end
