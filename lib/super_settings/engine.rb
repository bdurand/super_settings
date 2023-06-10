# frozen_string_literal: true

module SuperSettings
  # Engine that is loaded in a Rails environment. The engine will take care of applying any
  # settings overriding behavior in the Configuration as well as eager loading the settings
  # into memory.
  class Engine < Rails::Engine
    initializer("SuperSettings") do
      Rails.configuration.middleware.unshift(SuperSettings::Context::RackMiddleware)

      if defined?(ActiveJob::Base.around_perform)
        ActiveJob::Base.around_perform do |job, block|
          SuperSettings.context(&block)
        end
      end

      if defined?(Sidekiq.server?) && Sidekiq.server?
        require_relative "context/sidekiq_middleware"

        Sidekiq.configure_server do |sidekiq_config|
          sidekiq_config.server_middleware do |chain|
            chain.prepend(SuperSettings::Context::SidekiqMiddleware)
          end
        end
      end
    end

    config.after_initialize do
      # Call the deferred initialization block.
      configuration = Configuration.instance
      configuration.call

      SuperSettings.refresh_interval = configuration.refresh_interval unless configuration.refresh_interval.nil?

      reloader = if defined?(Rails.application.reloader.to_prepare)
        Rails.application.reloader
      elsif defined?(ActiveSupport::Reloader.to_prepare)
        ActiveSupport::Reloader
      elsif defined?(ActionDispatch::Reloader.to_prepare)
        ActionDispatch::Reloader
      end

      create_controller = lambda do
        klass = Class.new(configuration.controller.superclass || ::ApplicationController)
        if defined?(SuperSettings::SettingsController)
          SuperSettings.send(:remove_const, :SettingsController)
        end
        SuperSettings.const_set(:SettingsController, klass)
        klass.include(ControllerActions)
        if configuration.controller.enhancement
          klass.class_eval(&configuration.controller.enhancement)
        end
      end

      # Setup the controller.
      ActiveSupport.on_load(:action_controller) do
        create_controller.call
        if reloader && !Rails.configuration.cache_classes
          reloader.to_prepare(&create_controller)
        end
      end

      model_load_block = proc do
        Setting.cache = (configuration.model.cache || Rails.cache)
        Setting.storage = configuration.model.storage_class

        if !SuperSettings.loaded?
          begin
            SuperSettings.load_settings
          rescue => e
            Rails.logger&.warn(e)
          end
        end
      end

      if configuration.model.storage.to_s == "active_record"
        ActiveSupport.on_load(:active_record, &model_load_block)
      else
        model_load_block.call
      end
    end
  end
end
