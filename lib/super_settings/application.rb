# frozen_string_literal: true

require_relative "application/helper"

module SuperSettings
  class Application
    include Helper

    def render(erb_file)
      template = ERB.new(File.read(File.expand_path(File.join("application", erb_file), __dir__)))
      template.result(binding)
    end
  end
end
