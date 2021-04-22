# frozen_string_literal: true

require "singleton"

module SuperSettings
  class Configuration
    include Singleton

    attr_accessor :settings_controller_superclass, :application_name, :application_logo, :application_link, :settings_controller_changed_by_method

    def defer(&block)
      @block = block
    end

    def call
      @block&.call(self)
      @block = nil
    end

    def setting_model_definition(&block)
      if block
        @setting_model_definition = block
      elsif defined?(@setting_model_definition)
        @setting_model_definition
      end
    end

    def settings_controller_definition(&block)
      if block
        @settings_controller_definition = block
      elsif defined?(@settings_controller_definition)
        @settings_controller_definition
      end
    end
  end
end
