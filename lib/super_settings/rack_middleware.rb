# frozen_string_literal: true

module SuperSettings
  class RackMiddleware
    def initialize(app, path_prefix = "/")
      @app = app
      @path_prefix = path_prefix
    end

    def call(env)
    end
  end
end
