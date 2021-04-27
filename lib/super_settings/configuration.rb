# frozen_string_literal: true

require "singleton"

module SuperSettings
  # Configuration for the gem when run as a Rails engine. Default values and behaviors
  # on the controller and model can be overridden with the configuration.
  #
  # The configuration is a singleton instance.
  class Configuration
    include Singleton

    # Configuration for the controller.
    class Controller
      attr_reader :enhancement

      # Superclass for the controller. This should normally be set to one of your existing
      # base controller classes since these probably have authentication methods, etc. defined
      # on them. If this is not defined, the superclass will be `SuperSettings::ApplicationController`.
      attr_accessor :superclass

      # Optinal name of the application displayed in the view.
      attr_accessor :application_name

      # Optional mage URL for the application logo.
      attr_accessor :application_logo

      # Optional URL for a link back to the rest of the application.
      attr_accessor :application_link

      # Enhance the controller. You can define methods or call controller class methods like
      # `before_action`, etc. in the block. These will be applied to the engine controller.
      # This is essentially the same a monkeypatching the controller class.
      def enhance(&block)
        @enhancement = block
      end

      # Define how the `changed_by` attibute on the setting history will be filled from the controller.
      # The block will be evaluated in the context of the controller when the settings are changed.
      # The value returned by the block will be stored in the changed_by attribute. For example, if
      # your base controller class defines a method `current_user` and you'd like the name to be stored
      # in the history, you could call `define_changed_by { current_user.name }`
      def define_changed_by(&block)
        @changed_by_block = block
      end

      # Return the value of `define_changed_by` block.
      def changed_by(controller)
        if defined?(@changed_by_block) && @changed_by_block
          controller.instance_eval(&@changed_by_block)
        end
      end
    end

    # Configuration for the models.
    class Model
      attr_reader :enhancement, :history_enhancement

      # Provide additional enhancements to the SuperSettings::Setting model. You can define methods
      # on the model or call class methods like `after_save` if you want to define additional
      # logic or behavior on the model. This is essentially the same as monkeypatching the class.
      def enhance(&block)
        @enhancement = block
      end

      # Provide additional enhancements to the SuperSettings::History model. You can define methods
      # on the model or call class methods like `after_save` if you want to define additional
      # logic or behavior on the model. This is essentially the same as monkeypatching the class.
      def enhance_history(&block)
        @history_enhancement = block
      end
    end

    # Return the model specific configuration object.
    attr_reader :model

    # Return the controller specific configuration object.
    attr_reader :controller

    def initialize
      @model = Model.new
      @controller = Controller.new
    end

    def defer(&block)
      @block = block
    end

    def call
      @block&.call(self)
      @block = nil
    end

    # Set the cache used by SuperSettings::Setting.
    def cache=(cache_store)
      Setting.cache = cache_store
    end

    # Set the local cache refresh interval on SuperSettings.
    def refresh_interval=(seconds)
      SuperSettings.refresh_interval = seconds
    end

    # Enable tracking when keys are used on SuperSettings.
    def track_last_used=(value)
      SuperSettings.track_last_used = value
    end
  end
end
