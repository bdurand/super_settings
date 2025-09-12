# frozen_string_literal: true

module SuperSettings
  # Context classes for maintaining consistent state during execution blocks.
  # These contexts ensure that settings and random values remain constant
  # within a specific execution scope.
  module Context
    autoload :Current, File.join(__dir__, "context/current")
    autoload :RackMiddleware, File.join(__dir__, "context/rack_middleware")
    autoload :SidekiqMiddleware, File.join(__dir__, "context/sidekiq_middleware")
  end
end
