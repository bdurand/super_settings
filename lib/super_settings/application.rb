# frozen_string_literal: true

require_relative "application/helper"

module SuperSettings
  # Simple class for rendering ERB templates for the HTML application.
  class Application
    include Helper

    # @param layout [String, Symbol] path to an ERB template to use as the layout around the application UI. You can
    #                                pass the symbol +:default+ to use the default layout that ships with the gem.
    # @param add_to_head [String] HTML code to add to the <head> element on the page.
    def initialize(namespace:, layout: nil, add_to_head: nil)
      if layout
        @namespace = namespace
        layout = File.expand_path(File.join("application", "layout.html.erb"), __dir__) if layout == :default
        @layout = ERB.new(File.read(layout))
        @add_to_head = add_to_head
      end
    end

    # Render the specified ERB file in the lib/application directory distributed with the gem.
    #
    # @return [void]
    def render(erb_file)
      template = ERB.new(File.read(File.expand_path(File.join("application", erb_file), __dir__)))
      html = template.result(binding)
      if @layout
        render_layout { html }
      else
        html
      end
    end

    private

    def render_layout
      @layout.result(binding)
    end
  end
end
