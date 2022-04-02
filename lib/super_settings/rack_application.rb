# frozen_string_literal: true

require "rack"

module SuperSettings
  # Rack middleware for serving the REST API. See SuperSettings::RestAPI for more details on usage.
  #
  # The routes for the API can be mounted under a common path prefix specified in the initializer.
  #
  # You must specify some kind of authentication to use this class by at least overriding the
  # `authenticated?` method in a subclass. How you do this is left up to you since you will most
  # likely want to integrate in with how the rest of your application authenticates requests.
  #
  # You are also responsible for implementing any CSRF protection if your authentication method
  # uses stateful requests (i.e. cookies or Basic auth where browser automatically include the
  # credentials on every reqeust). There are other gems available that can be integrated into
  # your middleware stack to provide this feature. If you need to inject meta elements into
  # the page, you can do so with the `add_to_head` method.
  class RackApplication
    RESPONSE_HEADERS = {"Content-Type" => "application/json; charset=utf-8"}.freeze

    # @param app [Object] Rack application or middleware for unhandled requests
    # @param prefix [String] path prefix for the API routes.
    def initialize(app = nil, path_prefix = "/", &block)
      @app = app
      @path_prefix = path_prefix.to_s.chomp("/")
    end

    def call(env)
      if @path_prefix.empty? || "#{env["SCRIPT_NAME"]}#{env["PATH_INFO"]}".start_with?(@path_prefix)
        handle_request(env)
      else
        @app.call(env)
      end
    end

    protected

    # Subclasses must implement this method.
    # @param user [Object] the value returned by the `current_user` method.
    # @return [Boolean] true if the user is authenticated.
    def authenticated?(user)
      raise NotImplementedError
    end

    # Subclasses can override this method to indicate if the specified user is allowed to view settings.
    # @param user [Object] the value returned by the `current_user` method.
    # @return [Boolean] true if the user is can view settings.
    def allow_read?(user)
      true
    end

    # Subclasses can override this method to indicate if the specified user is allowed to change settings.
    # @param user [Object] the value returned by the `current_user` method.
    # @return [Boolean] true if the user is can change settings.
    def allow_write?(user)
      true
    end

    # Subclasses can override this method to return the current user object. This object will
    # be passed to the authenticated?, allow_read?, allow_write?, and changed_by methods.
    # @param request [Rack::Request] current reqeust object
    # @return [Object]
    def current_user(request)
      nil
    end

    # Subclasses can override this method to return the information about the current user that will
    # be stored in the setting history when a setting is changed.
    # @return [String]
    def changed_by(user)
      nil
    end

    # Subclasses can override this method to return the path to an ERB file to use as the layout
    # for the HTML application. The layout can use any of the methods defined in SuperSettings::Application::Helper.
    # @return [String]
    def layout
      "layout.html.erb"
    end

    # Subclasses can override this method to add custom HTML to the <head> element in the HTML application.
    # This can be used to add additional script or meta tags needed for CSRF protection, etc.
    # @param request [Rack::Request] current reqeust object
    # @return [String]
    def add_to_head(request)
    end

    # Subclasses can override this method to disable the web UI component of the application on only
    # expose the REST API.
    def web_ui_enabled?
      true
    end

    private

    def handle_request(env)
      request = Rack::Request.new(env)
      path = request.path[@path_prefix.length, request.path.length]
      if request.get?
        if (path == "/" || path == "") && web_ui_enabled?
          return handle_root_request(request)
        elsif path == "/settings"
          return handle_index_request(request)
        elsif path == "/setting"
          return handle_show_request(request)
        elsif path == "/setting/history"
          return handle_history_request(request)
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
        [404, {"Content-Type" => "text/plain"}, ["Not found"]]
      end
    end

    def handle_root_request(request)
      response = check_authorization(request, write_required: true) do |user|
        [200, {"Content-Type" => "text/html; charset=utf-8"}, [Application.new(:default, add_to_head(request)).render("index.html.erb")]]
      end

      if [401, 403].include?(response.first)
        if SuperSettings.authentication_url
          response = [302, {"Location" => SuperSettings.authentication_url}, []]
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
      yield(user)
    end

    def json_response(status, payload)
      [status, RESPONSE_HEADERS, [payload.to_json]]
    end

    def post_params(request)
      if request.content_type.to_s.match?(/\Aapplication\/json/i) && request.body
        request.params.merge(JSON.parse(request.body.string))
      else
        request.params
      end
    end
  end
end
