# frozen_string_literal: true

require "singleton"

module SuperSettings
  class Configuration

    include Singleton

    attr_writer :settings_controller_superclass
    attr_accessor :application_name, :application_logo, :application_link, :setting_info_link

    def defer(&block)
      @block = block
    end

    def call
      @block.call(self) if @block
      @block = nil
    end

    def settings_controller_superclass
      if defined?(@settings_controller_superclass) && @settings_controller_superclass
        @settings_controller_superclass
      else
        SuperSettings::ApplicationController
      end
    end

    def setting_model_definition(&block)
      if block
        @setting_model_definition = block
      else
        @setting_model_definition
      end
    end

    def settings_controller_definition(&block)
      if block
        @settings_controller_definition = block
      else
        @settings_controller_definition
      end
    end

  end
end
