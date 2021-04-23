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

    def super_settings_javascript_tag
      content_tag(:script) do
        render(file: File.join(__dir__, "scripts.js")).html_safe
      end
    end

    def super_settings_style_tag
      content_tag(:style, type: "text/css") do
        render(file: File.join(__dir__, "styles.css")).html_safe
      end
    end

    def super_settings_icon(name, options = {})
      svg = ICON_SVG[name.to_s]
      if options[:color].present?
        svg = svg.gsub("currentColor", options[:color])
      end
      css = DEFAULT_ICON_STYLE.merge(options[:style] || {}).map { |name, value| "#{name}:#{value}" }.join("; ")
      options = {alt: ""}.merge(options).merge(style: css)
      image_tag("data:image/svg+xml;utf8,#{svg}", options)
    end

    def super_settings_setting_info(setting)
      "Created: #{I18n.localize(setting.created_at, format: :long)}\nUpdated: #{I18n.localize(setting.updated_at, format: :long)}"
    end

    def super_settings_icon_button(icon, title:, color:, js_class:, url: nil, style: {})
      url = "#" if url.blank?
      link_to(url, class: js_class, title: title) do
        super_settings_icon(icon, color: color, style: ICON_BUTTON_STYLE.merge(style))
      end
    end

    def application_name
      config.application_name || "Application"
    end

    def application_header
      config = Configuration.instance
      content = "#{application_name} Settings"
      if config.application_logo.present?
        content = image_tag(config.application_logo).concat(content)
      end
      if config.application_link
        link_to(content, config.application_link)
      else
        content
      end
    end
  end
end
