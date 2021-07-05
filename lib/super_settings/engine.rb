# frozen_string_literal: true

module SuperSettings
  # Engine that is loaded in a Rails environment. The engine will take care of applying any
  # settings overriding behavior in the Configuration as well as eager loading the settings
  # into memory.
  class Engine < Rails::Engine
    isolate_namespace SuperSettings

    config.after_initialize do
      # Call the deferred initialization block.
      configuration = Configuration.instance
      configuration.call

      SuperSettings.refresh_interval = configuration.refresh_interval unless configuration.refresh_interval.nil?

      # Setup the controller.
      ActiveSupport.on_load(:action_controller) do
        klass = Class.new(configuration.controller.superclass || ::ApplicationController)
        SuperSettings.const_set(:SettingsController, klass)
        klass.include(ControllerActions)
        if configuration.controller.enhancement
          klass.class_eval(&configuration.controller.enhancement)
        end
      end

      model_load_block = proc do
        Setting.cache = (configuration.model.cache || Rails.cache)
        Setting.storage = configuration.model.storage_class

        if configuration.secret.present?
          SuperSettings.secret = configuration.secret
          configuration.secret = nil
        end

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
