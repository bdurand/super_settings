# frozen_string_literal: true

require "singleton"

module SuperSettings
  class Configuration
    include Singleton

    class Controller
      attr_reader :enhancement
      attr_accessor :superclass, :application_name, :application_logo, :application_link
      
      def enhance(&block)
        @enhancement = block
      end
      
      def define_changed_by(&block)
        @changed_by_block = block
      end
      
      def changed_by(controller)
        if defined?(@changed_by_block) && @changed_by_block
          controller.instance_eval(&@changed_by_block)
        end
      end
    end

    class Model
      attr_reader :enhancement
            
      def enhance(&block)
        @enhancement = block
      end
    end
    
    attr_reader :model, :controller
    
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
  end
end
