# frozen_string_literal: true

module SuperSettings
  class Engine < Rails::Engine
    isolate_namespace ::SuperSettings

    config.after_initialize do
      configuration = Configuration.instance
      configuration.call

      ActiveSupport.on_load(:action_controller) do
        klass = Class.new(configuration.controller.superclass || ApplicationController)
        SuperSettings.const_set(:SettingsController, klass)
        klass.include(ControllerActions)
        if configuration.controller.enhancement
          klass.class_eval(&configuration.controller.enhancement)
        end
      end

      ActiveSupport.on_load(:active_record) do
        puts "ENGINE<br>"
        if configuration.model.enhancement
          Setting.class_eval(&configuration.model.enhancement)
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
