# frozen_string_literal: true

module SuperSettings
  module Helper
    ICON_SVG = Dir.glob(File.join(__dir__, "images", "*.svg")).each_with_object({}) do |file, cache|
      cache[File.basename(file, ".svg")] = File.read(file).chomp
    end.freeze

    ICON_BUTTON_STYLE = {
      cursor: "pointer",
      width: "1.5rem",
      height: "1.5rem",
      "min-width": "20px",
      "min-height": "20px",
      "margin-top": "0.25rem",
      "margin-right": "0.5rem"
    }.freeze

    DEFAULT_ICON_STYLE = {
      width: "1rem",
      height: "1rem",
      display: "inline-block",
      "vertical-align": "middle"
    }.freeze

    # Render the scripts.js file as an inline <script> tag.
    def javascript_tag
      <<~HTML
        <script>
          #{File.read(File.join(__dir__, "scripts.js"))}
          #{File.read(File.join(__dir__, "api.js"))}
        </script>
      HTML
    end

    # Render the styles.css as an inline <style> tag.
    def style_tag
      <<~HTML
        <style type="text/css">
          #{File.read(File.join(__dir__, "styles.css"))}
        </style>
      HTML
    end

    # Render the styles.css as an inline <style> tag.
    def layout_style_tag
      <<~HTML
        <style type="text/css">
          #{File.read(File.join(__dir__, "layout_styles.css"))}
        </style>
      HTML
    end

    # Render an image tag for one of the SVG images in the images directory. If the :color option
    # is specified, it will be applied to the SVG image.
    def icon_image(name, options = {})
      svg = ICON_SVG[name.to_s]
      if Coerce.present?(options[:color])
        svg = svg.gsub("currentColor", options[:color])
      end
      css = DEFAULT_ICON_STYLE.merge(options[:style] || {}).map { |name, value| "#{name}:#{value}" }.join("; ")
      options = {alt: ""}.merge(options).merge(src: "data:image/svg+xml;utf8,#{svg}", style: css)
      tag(:img, options)
    end

    # Render an icon image as a link tag.
    def icon_button(icon, title:, color:, js_class:, url: nil, disabled: false, style: {}, link_style: nil)
      url = "#" if Coerce.blank?(url)
      image = icon_image(icon, alt: title, color: color, style: ICON_BUTTON_STYLE.merge(style))
      content_tag(:a, image, href: url, class: js_class, disabled: disabled, style: link_style)
    end

    # Return the application name set by the configuration or a default value.
    def application_name
      Configuration.instance.controller.application_name || "Application"
    end

    # Render the header for the web pages using values set in the configuration.
    def application_header
      config = Configuration.instance.controller
      content = ERB::Util.html_escape("#{application_name} Settings")
      if Coerce.present?(config.application_logo)
        content = tag(:img, src: config.application_logo, alt: "") + content
      end
      if config.application_link
        content_tag(:a, content, href: config.application_link)
      else
        content
      end
    end

    def tag(tag, options)
      "<#{tag} #{html_attributes(options)}>"
    end

    def content_tag(tag, body, options)
      "<#{tag} #{html_attributes(options)}>#{body}</#{tag}>"
    end

    def html_attributes(options)
      html_options = []
      options.each do |name, value|
        html_options << "#{name}=\"#{ERB::Util.html_escape(value.to_s)}\""
      end
      html_options.join(" ")
    end
  end
end
