# frozen_string_literal: true

module SuperSettings
  # Helper functions used for rendering the Super Settings HTML application. These methods
  # are mixed in to the Application class so they are accessible from the ERB templates.
  module Helper
    ICON_SVG = Dir.glob(File.join(__dir__, "images", "*.svg")).each_with_object({}) do |file, cache|
      svg = File.read(file).chomp
      svg.sub!(/width="[^"]+"/, 'width="100%"')
      svg.sub!(/height="[^"]+"/, 'height="100%"')
      cache[File.basename(file, ".svg")] = svg
    end.freeze

    ICON_BUTTON_STYLE = {
      cursor: "pointer",
      width: "1.35rem",
      height: "1.35rem",
      "min-width": "20px",
      "min-height": "20px",
      "margin-top": "0.25rem",
      "margin-right": "0.5rem"
    }.freeze

    DEFAULT_ICON_STYLE = {
      width: "1rem",
      height: "1rem",
      display: "inline-block"
    }.freeze

    # Render the scripts.js file as an inline <script> tag.
    def javascript_tag
      <<~HTML
        <script>
          #{File.read(File.join(__dir__, "scripts.js"))}
          #{File.read(File.join(__dir__, "api.js"))}
          #{"SuperSettingsAPI.authenticationUrl = '#{SuperSettings.authentication_url.gsub("'", "\\'")}';" if SuperSettings.authentication_url}
          #{SuperSettings.web_ui_javascript}
        </script>
      HTML
    end

    # Render the styles.css as an inline <style> tag.
    def style_tag
      <<~HTML
        <style type="text/css">
          #{render_partial("style_vars.css.erb")}
          #{File.read(File.join(__dir__, "styles.css"))}
        </style>
      HTML
    end

    # Render the styles.css as an inline <style> tag.
    def layout_style_tag
      <<~HTML
        <style type="text/css">
          #{render_partial("layout_vars.css.erb")}
          #{File.read(File.join(__dir__, "layout_styles.css"))}
        </style>
      HTML
    end

    # Render an ERB template.
    #
    # @param erb_file [String] the path to the ERB file to render
    # @return [String] the rendered HTML
    def render_partial(erb_file)
      template = ERB.new(File.read(File.expand_path(erb_file, __dir__)))
      template.result(binding)
    end

    # Escape text for use in HTML.
    #
    # @param text [String] the text to escape
    # @return [String] the escaped text
    def html_escape(text)
      ERB::Util.html_escape(text)
    end

    # Render an image tag for one of the SVG images in the images directory. If the :color option
    # is specified, it will be applied to the SVG image.
    def icon_image(name, options = {})
      svg = ICON_SVG[name.to_s]
      style = {display: "inline-block"}.merge(options[:style] || {})
      css = DEFAULT_ICON_STYLE.merge(style).map { |name, value| "#{name}: #{value}" }.join("; ")
      options = options.merge(style: css)
      if options[:data].is_a?(Hash)
        options[:data].each do |key, value|
          options["data-#{key}"] = value
        end
        options.delete(:data)
      end
      content_tag(:span, svg, options)
    end

    # Render an icon image as a link tag.
    def icon_button(icon, title:, color:, js_class:, url: nil, disabled: false, style: {}, link_style: nil)
      url = "#" if Coerce.blank?(url)
      image = icon_image(icon, alt: title, style: ICON_BUTTON_STYLE.merge(style).merge(color: color))
      content_tag(:a, image, href: url, class: js_class, disabled: disabled, style: link_style)
    end

    # Return the application name set by the configuration or a default value.
    def application_name
      html_escape(SuperSettings.configuration.controller.application_name || "Application")
    end

    # Render the header for the web pages using values set in the configuration.
    def application_header
      config = SuperSettings.configuration.controller
      content = html_escape("#{application_name} Settings")
      if Coerce.present?(config.application_logo)
        content = tag(:img, src: config.application_logo, alt: "") + content
      end
      if config.application_link
        content_tag(:a, content, href: config.application_link)
      else
        content
      end
    end

    # Render an HTML tag without any body content.
    def tag(tag, options)
      "<#{tag} #{html_attributes(options)}>"
    end

    # Render an HTML tag with body content.
    def content_tag(tag, body, options)
      "<#{tag} #{html_attributes(options)}>#{body}</#{tag}>"
    end

    # Format a hash into HTML attributes.
    def html_attributes(options)
      html_options = []
      options.each do |name, value|
        html_options << "#{name}=\"#{html_escape(value.to_s)}\""
      end
      html_options.join(" ")
    end

    # Additional HTML code that should go into the <head> element on the page.
    #
    # @return [String]
    def add_to_head
      @add_to_head if defined?(@add_to_head)
    end

    # The base URL for the REST API.
    #
    # @return [String]
    def api_base_url
      @api_base_url if defined?(@api_base_url)
    end

    # Whether to use dark mode for the application UI.
    #
    # @return [Boolean, nil]
    def color_scheme
      @color_scheme if defined?(@color_scheme)
    end
  end
end
