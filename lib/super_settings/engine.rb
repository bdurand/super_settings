# frozen_string_literal: true

module SuperSettings
  class Engine < Rails::Engine
    isolate_namespace ::SuperSettings

    config.after_initialize do
      configuration = Configuration.instance
      configuration.call

      ActiveSupport.on_load(:action_controller) do
        application_controller_class = (configuration.settings_controller_superclass || ApplicationController)
        klass = Class.new(application_controller_class)
        SuperSettings.const_set(:SettingsController, klass)
        klass.include(ControllerActions)
        if configuration.settings_controller_definition
          klass.class_eval(&configuration.settings_controller_definition)
        end
      end

      ActiveSupport.on_load(:active_record) do
        puts "ENGINE<br>"
        if configuration.setting_model_definition
          Setting.class_eval(&configuration.setting_model_definition)
        end

        if Setting.table_exists?
          begin
            SuperSettings.load_settings
          rescue => e
            Rails.logger&.warn(e)
          end
        end
      end
    end
  end
end
