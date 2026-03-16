# frozen_string_literal: true

module SuperSettings
  # Rack middleware for serving the REST API. See SuperSettings::RestAPI for more details on usage.
  #
  # The routes for the API can be mounted under a common path prefix specified in the initializer.
  #
  # You must specify some kind of authentication to use this class by at least overriding the
  # +authenticated?+ method in a subclass. How you do this is left up to you since you will most
  # likely want to integrate in with how the rest of your application authenticates requests.
  #
  # You are also responsible for implementing any CSRF protection if your authentication method
  # uses stateful requests (i.e. cookies or Basic auth where browser automatically include the
  # credentials on every request). There are other gems available that can be integrated into
  # your middleware stack to provide this feature. If you need to inject meta elements into
  # the page, you can do so with the +add_to_head+ method.
  class RackApplication
    RESPONSE_HEADERS = {"content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache"}.freeze

    # @param app [Object] Rack application or middleware for unhandled requests
    # @param path_prefix [String] path prefix for the API routes.
    # @yield Block to be evaluated on the instance to extend it's behavior. You can use
    #   this to define the access control methods rather than having to extend the class.
    #
    # @example
    #
    #   app = SuperSettings::RackApplication.new do
    #     def current_user(request)
    #       auth = request["HTTP_AUTHORIZATION"]
    #       token_match = auth&.match(/\ABearer:\s*(.*)/)
    #       token = token_match[1] if token_match
    #       User.identified_by(token)
    #     end
    #
    #     def allow_write?(user)
    #       user.admin?
    #     end
    #   end
    def initialize(app = nil, path_prefix = "/", &block)
      # Requiring rack here so that the gem does not have a hard dependency on it.
      begin
        require "rack"
      rescue LoadError
        raise LoadError, "SuperSettings::RackApplication requires the rack gem"
      end

      @app = app
      @path_prefix = path_prefix.to_s.chomp("/")
      instance_eval(&block) if block
    end

    def call(env)
      if @path_prefix.empty? || "#{env["SCRIPT_NAME"]}#{env["PATH_INFO"]}".start_with?(@path_prefix)
        handle_request(env)
      else
        @app.call(env)
      end
    end

    # Subclasses must override this method to return the current user object. This object will
    # be passed to the authenticated?, allow_read?, allow_write?, and changed_by methods.
    #
    # @param request [Rack::Request] current request object
    # @return [Object]
    def current_user(request)
      raise NotImplementedError
    end

    # Subclasses can override this method to indicate if a user is authenticated. By default
    # a request will be considered authenticated if the +current_user+ method returns a value.
    #
    # @param user [Object] the value returned by the +current_user+ method.
    # @return [Boolean] true if the user is authenticated.
    def authenticated?(user)
      !!user
    end

    # Subclasses can override this method to indicate if the specified user is allowed to view settings.
    # By default if a user is authenticated they will be able to read settings.
    #
    # @param user [Object] the value returned by the +current_user+ method.
    # @return [Boolean] true if the user is can view settings.
    def allow_read?(user)
      true
    end

    # Subclasses can override this method to indicate if the specified user is allowed to change settings.
    # By default if a user can read settings, then they will be able to write them as well.
    #
    # @param user [Object] the value returned by the +current_user+ method.
    # @return [Boolean] true if the user is can change settings.
    def allow_write?(user)
      allow_read?(user)
    end

    # Subclasses can override this method to return the information to record about the current user
    # that will be stored in the setting history when a setting is changed.
    #
    # @return [String]
    def changed_by(user)
      nil
    end

    # Subclasses can override this method to return the path to an ERB file to use as the layout
    # for the HTML application. The layout can use any of the methods defined in SuperSettings::Application::Helper.
    #
    # @return [String]
    def layout
      "layout.html.erb"
    end

    # Subclasses can override this method to add custom HTML to the <head> element in the HTML application.
    # This can be used to add additional script or meta tags needed for CSRF protection, etc.
    #
    # @param request [Rack::Request] current reqeust object
    # @return [String]
    def add_to_head(request)
    end

    # Subclasses can override this method to disable the web UI component of the application on only
    # expose the REST API.
    #
    # @return [Boolean]
    def web_ui_enabled?
      SuperSettings.configuration.controller.web_ui_enabled?
    end

    private

    def handle_request(env)
      request = Rack::Request.new(env)
      path = request.path[@path_prefix.length, request.path.length]
      if request.get?
        if (path == "/" || path == "") && web_ui_enabled?
          return handle_root_request(request)
        elsif path == "/authorized"
          return handle_authorization_request(request)
        elsif path == "/api.js"
          return handle_api_js_request(request)
        elsif path == "/settings"
          return handle_index_request(request)
        elsif path == "/setting/history"
          return handle_history_request(request)
        elsif path == "/setting"
          return handle_show_request(request)
        elsif path == "/last_updated_at"
          return handle_last_updated_at_request(request)
        elsif path == "/updated_since"
          return handle_updated_since_request(request)
        end
      elsif request.post?
        if path == "/settings"
          return handle_update_request(request)
        end
      end

      if @app
        @app.call(env)
      else
        [404, {"content-type" => "text/plain"}, ["Not found"]]
      end
    end

    def handle_authorization_request(request)
      check_authorization(request) do |user|
        read_only = !allow_write?(user) || !!request.env["super_settings.read_only"]
        permission = read_only ? "read-only" : "read-write"
        payload = {authorized: true, permission: permission}
        [200, {"content-type" => "application/json; charset=utf-8", "cache-control" => "no-cache", "super-settings-permission" => permission}, [JSON.generate(payload)]]
      end
    end

    def handle_api_js_request(request)
      check_authorization(request) do |user|
        js = File.read(File.expand_path(File.join("application", "api.js"), __dir__))
        [200, {"content-type" => "application/javascript; charset=utf-8", "cache-control" => "no-cache"}, [js]]
      end
    end

    def handle_root_request(request)
      response = check_authorization(request) do |user|
        read_only = !allow_write?(user) || !!request.env["super_settings.read_only"]
        locale = resolve_locale(request)
        headers = {"content-type" => "text/html; charset=utf-8", "cache-control" => "no-cache"}
        lang = request.GET["lang"] if request.respond_to?(:GET)
        if lang && SuperSettings::MiniI18n.available_locales.include?(lang)
          headers["set-cookie"] = "super_settings_locale=#{lang}; path=/; SameSite=Lax"
        end
        [200, headers, [Application.new(layout: :default, add_to_head: add_to_head(request), color_scheme: SuperSettings.configuration.controller.color_scheme, read_only: read_only, locale: locale).render]]
      end

      if [401, 403].include?(response.first)
        if SuperSettings.authentication_url
          response = [302, {"location" => SuperSettings.authentication_url}, []]
        end
      end

      response
    end

    def handle_index_request(request)
      check_authorization(request) do |user|
        json_response(200, RestAPI.index)
      end
    end

    def handle_show_request(request)
      check_authorization(request) do |user|
        setting = RestAPI.show(request.params["key"])
        if setting
          json_response(200, setting)
        else
          json_response(404, nil)
        end
      end
    end

    def handle_update_request(request)
      check_authorization(request, write_required: true) do |user|
        result = SuperSettings::RestAPI.update(post_params(request)["settings"], changed_by(user))
        if result[:success]
          json_response(200, result)
        else
          json_response(422, result)
        end
      end
    end

    def handle_history_request(request)
      check_authorization(request) do |user|
        history = RestAPI.history(request.params["key"], limit: request.params["limit"], offset: request.params["offset"])
        if history
          json_response(200, history)
        else
          json_response(404, nil)
        end
      end
    end

    def handle_last_updated_at_request(request)
      check_authorization(request) do |user|
        json_response(200, RestAPI.last_updated_at)
      end
    end

    def handle_updated_since_request(request)
      check_authorization(request) do |user|
        json_response(200, RestAPI.updated_since(request.params["time"]))
      end
    end

    def check_authorization(request, write_required: false)
      user = current_user(request)
      return json_response(401, error: "Authentiation required") unless authenticated?(user)

      allowed = (write_required ? allow_write?(user) : allow_read?(user))
      return json_response(403, error: "Access denied") unless allowed

      if write_required && request.env["super_settings.read_only"]
        return json_response(403, error: "Access denied")
      end

      yield(user)
    end

    def json_response(status, payload)
      [status, RESPONSE_HEADERS.dup, [payload.to_json]]
    end

    # Determine the locale for a request. Precedence:
    # 1. ?lang= query parameter
    # 2. super_settings_locale cookie (set by the language picker)
    # 3. Accept-Language header
    # 4. Default locale
    def resolve_locale(request)
      available = SuperSettings::MiniI18n.available_locales

      # 1. Explicit query parameter
      lang = request.GET["lang"] if request.respond_to?(:GET)
      return lang if lang && available.include?(lang)

      # 2. Cookie
      cookie = request.cookies["super_settings_locale"] if request.respond_to?(:cookies)
      return cookie if cookie && available.include?(cookie)

      # 3. Accept-Language header
      accept = request.env["HTTP_ACCEPT_LANGUAGE"] if request.respond_to?(:env)
      locale_from_accept_language(accept.to_s, available) || SuperSettings::MiniI18n::DEFAULT_LOCALE
    end

    # Parse the Accept-Language header and return the best matching locale.
    def locale_from_accept_language(header, available)
      return nil if header.nil? || header.empty?

      # Parse tags with optional quality values, e.g. "en-US,en;q=0.9,fr;q=0.8"
      tags = header.split(",").map { |entry|
        parts = entry.strip.split(";")
        tag = parts[0].to_s.strip.downcase.tr("_", "-")
        q = 1.0
        parts[1..].each do |p|
          if p.strip.start_with?("q=")
            q = p.strip.sub("q=", "").to_f
          end
        end
        [tag, q]
      }.sort_by { |_, q| -q }

      tags.each do |tag, _|
        return tag if available.include?(tag)
        # Try language subtag
        lang = tag.split("-").first
        return lang if available.include?(lang)
      end

      nil
    end

    def post_params(request)
      if request.content_type.to_s.match?(/\Aapplication\/json/i) && request.body
        request.params.merge(JSON.parse(request.body.read))
      else
        request.params
      end
    end
  end
end
