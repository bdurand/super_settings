# frozen_string_literal: true

require_relative "application/helper"

module SuperSettings
  # Simple class for rendering ERB templates for the HTML application.
  class Application
    include Helper

    # @param layout [String, Symbol] path to an ERB template to use as the layout around the application UI. You can
    #                                pass the symbol +:default+ to use the default layout that ships with the gem.
    # @param add_to_head [String] HTML code to add to the <head> element on the page.
    # @param api_base_url [String] the base URL for the REST API.
    # @param color_scheme [Symbol] whether to use dark mode for the application UI. If +nil+, the user's system
    #                              preference will be used.
    def initialize(layout: nil, add_to_head: nil, api_base_url: nil, color_scheme: nil)
      if layout
        layout = File.expand_path(File.join("application", "layout.html.erb"), __dir__) if layout == :default
        @layout = ERB.new(File.read(layout)) if layout
        @add_to_head = add_to_head
      else
        @layout = nil
        @add_to_head = nil
      end

      @api_base_url = api_base_url
      @color_scheme = color_scheme&.to_sym
    end

    # Render the web UI application HTML.
    #
    # @return [void]
    def render
      template = ERB.new(File.read(File.expand_path(File.join("application", "index.html.erb"), __dir__)))
      html = template.result(binding)
      html = render_layout { html } if @layout
      html = html.html_safe if html.respond_to?(:html_safe)
      html
    end

    private

    def render_layout
      @layout&.result(binding)
    end
  end
end
