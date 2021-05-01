# frozen_string_literal: true

module SuperSettings
  module SettingsHelper
    ICON_SVG = Dir.glob(File.join(__dir__, "images", "*.svg")).each_with_object({}) do |file, cache|
      cache[File.basename(file, ".svg")] = File.read(file).chomp
    end.freeze

    ICON_BUTTON_STYLE = HashWithIndifferentAccess.new(
      :cursor => "pointer",
      :width => "1.5rem",
      :height => "1.5rem",
      "min-width" => "20px",
      "min-height" => "20px",
      "margin-top" => "0.25rem",
      "margin-right" => "0.5rem"
    ).freeze

    DEFAULT_ICON_STYLE = HashWithIndifferentAccess.new(
      "width" => "1rem",
      "height" => "1rem",
      "display" => "inline-block",
      "vertical-align" => "middle"
    ).freeze

    # Render the scripts.js file as an inline <script> tag.
    def super_settings_javascript_tag
      content_tag(:script) do
        render(file: File.join(__dir__, "scripts.js")).html_safe
      end
    end

    # Render the styles.css as an inline <style> tag.
    def super_settings_style_tag
      content_tag(:style, type: "text/css") do
        render(file: File.join(__dir__, "super_settings_styles.css")).html_safe
      end
    end

    # Render the styles.css as an inline <style> tag.
    def super_settings_layout_style_tag
      content_tag(:style, type: "text/css") do
        render(file: File.join(__dir__, "layout_styles.css")).html_safe
      end
    end

    # Render an image tag for one of the SVG images in the images directory. If the :color option
    # is specified, it will be applied to the SVG image.
    def super_settings_icon(name, options = {})
      svg = ICON_SVG[name.to_s]
      if options[:color].present?
        svg = svg.gsub("currentColor", options[:color])
      end
      css = DEFAULT_ICON_STYLE.merge(options[:style] || {}).map { |name, value| "#{name}:#{value}" }.join("; ")
      options = {alt: ""}.merge(options).merge(style: css)
      image_tag("data:image/svg+xml;utf8,#{svg}", options)
    end

    # Render an icon image as a link tag.
    def super_settings_icon_button(icon, title:, color:, js_class:, url: nil, disabled: false, style: {}, link_style: nil)
      url = "#" if url.blank?
      link_to(url, class: js_class, disabled: disabled, style: link_style) do
        super_settings_icon(icon, alt: title, color: color, style: ICON_BUTTON_STYLE.merge(style))
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

    def super_settings_last_used_age(last_used_at)
      return "never" if last_used_at.nil?
      hours = (Time.now - last_used_at) / 1.hour
      if hours <= 1
        "less than one hour ago"
      elsif hours <= 48
        "over #{pluralize(hours.floor, "hour")} ago"
      else
        "over #{pluralize((hours / 24).floor, "day")} ago"
      end
    end
  end
end
