# frozen_string_literal: true

module SuperSettings
  module Context
    # Rack middleware you can use to add a context to your requests so that
    # settings are not changed during request execution.
    #
    # This middleware is automatically added to Rails applications.
    class RackMiddleware
      def initialize(app)
        @app = app
      end

      def call(env)
        SuperSettings.context do
          @app.call(env)
        end
      end
    end
  end
end
