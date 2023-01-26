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
      # @api private
      attr_reader :enhancement

      # Superclass for the controller. This should normally be set to one of your existing
      # base controller classes since these probably have authentication methods, etc. defined
      # on them. If this is not defined, the superclass will be SuperSettings::ApplicationController.
      # It can be set to either a class or a class name. Setting to a class name is preferrable
      # since it will be compatible with class reloading in a development environment.
      attr_writer :superclass

      def superclass
        if defined?(@superclass) && @superclass.is_a?(String)
          @superclass.constantize
        else
          @superclass
        end
      end

      # Optinal name of the application displayed in the view.
      attr_accessor :application_name

      # Optional mage URL for the application logo.
      attr_accessor :application_logo

      # Optional URL for a link back to the rest of the application.
      attr_accessor :application_link

      # Optional URL for a link to the login page for the application.
      def authentication_url=(value)
        SuperSettings.authentication_url = value
      end

      # Javascript to inject into the settings application HTML page. This can be used, for example,
      # to set authorization credentials stored client side to access the settings API.
      def web_ui_javascript=(script)
        SuperSettings.web_ui_javascript = script
      end

      # Enable or disable the web UI (the REST API will always be enabled).
      attr_writer :web_ui_enabled

      def web_ui_enabled?
        unless defined?(@web_ui_enabled)
          @web_ui_enabled = true
        end
        !!@web_ui_enabled
      end

      # Enhance the controller. You can define methods or call controller class methods like
      # +before_action+, etc. in the block. These will be applied to the engine controller.
      # This is essentially the same a monkeypatching the controller class.
      #
      # @yield Block of code to inject into the controller class.
      def enhance(&block)
        @enhancement = block
      end

      # Define how the +changed_by+ attibute on the setting history will be filled from the controller.
      # The block will be evaluated in the context of the controller when the settings are changed.
      # The value returned by the block will be stored in the changed_by attribute. For example, if
      # your base controller class defines a method +current_user+ and you'd like the name to be stored
      # in the history, you could call
      #
      # @example
      #   define_changed_by { current_user.name }
      #
      # @yield Block of code to call on the controller at request time
      def define_changed_by(&block)
        @changed_by_block = block
      end

      # Return the value of +define_changed_by+ block.
      #
      # @api private
      def changed_by(controller)
        if defined?(@changed_by_block) && @changed_by_block
          controller.instance_eval(&@changed_by_block)
        end
      end
    end

    # Configuration for the models.
    class Model
      # Specify the cache implementation to use for caching the last updated timestamp for reloading
      # changed records. Defaults to Rails.cache
      attr_accessor :cache

      attr_writer :storage

      # Specify the storage engine to use for persisting settings. The value can either be specified
      # as a full class name or an underscored class name for a storage classed defined in the
      # SuperSettings::Storage namespace. The default storage engine is +SuperSettings::Storage::ActiveRecord+.
      def storage
        if defined?(@storage) && @storage
          @storage
        else
          :active_record
        end
      end

      # @return [Class]
      # @api private
      def storage_class
        if storage.is_a?(Class)
          storage
        else
          class_name = storage.to_s.camelize
          if Storage.const_defined?("#{class_name}Storage")
            Storage.const_get("#{class_name}Storage")
          else
            class_name.constantize
          end
        end
      end
    end

    # Return the model specific configuration object.
    attr_reader :model

    # Return the controller specific configuration object.
    attr_reader :controller

    # Set the number of seconds that settings will be cached locally before the database
    # is checked for updates. Defaults to 5 seconds.
    attr_accessor :refresh_interval

    def initialize
      @model = Model.new
      @controller = Controller.new
    end

    # Defer the execution of a block that will be yielded to with the config object. This
    # is needed in a Rails environment during initialization so that all the frameworks can
    # load before loading the settings.
    #
    # @api private
    def defer(&block)
      @block = block
    end

    # Call the block deferred during initialization.
    #
    # @api private
    def call
      @block&.call(self)
      @block = nil
    end
  end
end
