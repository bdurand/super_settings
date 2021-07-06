# frozen_string_literal: true

require "rack"

module SuperSettings
  class RackMiddleware
    RESPONSE_HEADERS = {"Content-Type" => "application/json; charset=utf-8"}.freeze

    def initialize(app, path_prefix = "/")
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

    def authenticated?(user)
      true
    end

    def allow_read?(user)
      true
    end

    def allow_write?(user)
      true
    end

    # Subclasses can override this method to return the current user object.
    def current_user(request)
      nil
    end

    def changed_by(user)
      nil
    end

    def layout
      "layout.html.erb"
    end

    private

    def handle_request(env)
      request = Rack::Request.new(env)
      path = request.path[@path_prefix.length, request.path.length]
      if request.get?
        if path == "/" || path == ""
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
      @app.call(env)
    end

    def handle_root_request(request)
      check_authorization(request) do |user|
        [200, {"Content-Type" => "text/html; charset=utf-8"}, [Application.new(:default).render("index.html.erb")]]
      end
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
