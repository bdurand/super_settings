# frozen_string_literal: true

require_relative "controller_actions"
require_relative "setting"

module SuperSettings
  class Engine < Rails::Engine

    isolate_namespace SuperSettings

    config.after_initialize do
      configuration = SuperSettings::Configuration.instance
      configuration.call

      klass = Class.new(configuration.settings_controller_superclass)
      SuperSettings.const_set(:SettingsController, klass)
      klass.include(SuperSettings::ControllerActions)
      if configuration.settings_controller_definition
        klass.instance_eval(&configuration.settings_controller_definition)
      end

      if configuration.setting_model_definition
        SuperSettings::Setting.instance_eval(&configuration.setting_model_definition)
      end
    end

  end
end
