# frozen_string_literal: true

module SuperSettings
  module Context
    # Sidekiq middleware you can use to add a context to your jobs so that
    # settings are not changed during job execution.
    #
    # @example
    #   require "super_settings/context/sidekiq_middleware"
    #
    #   Sidekiq.configure_server do |config|
    #     config.server_middleware do |chain|
    #       chain.add SuperSettings::Context::SidekiqMiddleware
    #     end
    #   end
    #
    # You can disable the context by setting the `super_settings_context` key
    # to `false` in the job payload.
    #
    # @example
    #   class MyWorker
    #     include Sidekiq::Worker
    #     sidekiq_options super_settings_context: false
    #   end
    class ServerMiddleware
      if defined?(Sidekiq::ServerMiddleware)
        include Sidekiq::ServerMiddleware
      end

      def call(job_instance, job_payload, queue)
        if job_payload["super_settings_context"] == false
          yield
        else
          SuperSettings.context do
            yield
          end
        end
      end
    end
  end
end
