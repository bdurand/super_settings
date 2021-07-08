# frozen_string_literal: true

require_relative "application/helper"

module SuperSettings
  class Application
    include Helper

    def initialize(layout = nil, add_to_head = nil)
      if layout
        layout = File.expand_path(File.join("application", "layout.html.erb"), __dir__) if layout == :default
        @layout = ERB.new(File.read(layout))
        @add_to_head = add_to_head
      end
    end

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
