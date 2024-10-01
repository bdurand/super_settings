# frozen_string_literal: true

module SuperSettings
  module SettingsHelper
    # Render the styles.css as an inline <style> tag.
    def super_settings_layout_style_tag
      application_dir = File.expand_path(File.join("..", "..", "..", "lib", "super_settings", "application"), __dir__)
      css = render(file: File.join(application_dir, "layout_styles.css"))
      content_tag(:style, type: "text/css") do
        (layout_css_vars + css).html_safe
      end
    end

    # Return the application name set by the configuration or a default value.
    def super_settings_application_name
      SuperSettings.configuration.controller.application_name || "Application"
    end

    # Render the header for the web pages using values set in the configuration.
    def super_settings_application_header
      config = SuperSettings.configuration.controller
      content = "#{super_settings_application_name} Settings"
      if Coerce.present?(config.application_logo)
        content = image_tag(config.application_logo, alt: "").concat(content)
      end
      if config.application_link
        link_to(content, config.application_link)
      else
        content
      end
    end

    private

    def layout_css_vars
      application_dir = File.expand_path(File.join("..", "..", "..", "lib", "super_settings", "application"), __dir__)
      erb = ERB.new(File.read(File.join(application_dir, "layout_vars.css.erb")))
      color_scheme = SuperSettings.configuration.controller.color_scheme
      erb.result(binding).html_safe
    end
  end
end
