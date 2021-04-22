# frozen_string_literal: true

require_relative "controller_actions"
require_relative "setting"

module SuperSettings
  class Engine < Rails::Engine

    isolate_namespace SuperSettings

    config.after_initialize do
      configuration = Configuration.instance
      configuration.call

      application_controller_class = (configuration.settings_controller_superclass || ApplicationController)
      klass = Class.new(application_controller_class)
      SuperSettings.const_set(:SettingsController, klass)
      klass.include(ControllerActions)
      if configuration.settings_controller_definition
        klass.class_eval(&configuration.settings_controller_definition)
      end

      if configuration.setting_model_definition
        Setting.class_eval(&configuration.setting_model_definition)
      end
    end

  end
end
