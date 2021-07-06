# frozen_string_literal: true

module SuperSettings
  module SettingsHelper
    # Render the styles.css as an inline <style> tag.
    def super_settings_layout_style_tag
      application_dir = File.expand_path(File.join("..", "..", "..", "lib", "super_settings", "application"), __dir__)
      content_tag(:style, type: "text/css") do
        render(file: File.join(application_dir, "layout_styles.css")).html_safe
      end
    end

    # Return the application name set by the configuration or a default value.
    def super_settings_application_name
      Configuration.instance.controller.application_name || "Application"
    end

    # Render the header for the web pages using values set in the configuration.
    def super_settings_application_header
      config = Configuration.instance.controller
      content = "#{super_settings_application_name} Settings"
      if config.application_logo.present?
        content = image_tag(config.application_logo, alt: "").concat(content)
      end
      if config.application_link
        link_to(content, config.application_link)
      else
        content
      end
    end
  end
end
