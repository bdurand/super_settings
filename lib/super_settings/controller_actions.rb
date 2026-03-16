# frozen_string_literal: true

require "erb"

module SuperSettings
  # Module used to build the SuperSettings::SettingsController for Rails applications.
  # This controller is defined at runtime since it is assumed that the superclass will
  # be one of the application's own base controller classes since the application will
  # want to define authentication and authorization criteria.
  #
  # The controller is built by extending the class defined by the Configuration object and
  # then mixing in this module.
  module ControllerActions
    def self.included(base)
      base.layout "super_settings/settings"
      base.helper SettingsHelper
      base.protect_from_forgery with: :exception, if: :protect_from_forgery?
    end

    # Render the HTML application for managing settings.
    def root
      html = SuperSettings::Application.new(read_only: super_settings_read_only?).render
      render html: html.html_safe, layout: true
    end

    # API endpoint for getting active settings. See SuperSettings::RestAPI for details.
    def index
      render json: SuperSettings::RestAPI.index
    end

    # API endpoint for getting a setting. See SuperSettings::RestAPI for details.
    def show
      setting = SuperSettings::RestAPI.show(params[:key])
      if setting
        render json: setting
      else
        render json: nil, status: 404
      end
    end

    # API endpoint for updating settings. See SuperSettings::RestAPI for details.
    def update
      if super_settings_read_only?
        render json: {error: "Access denied"}, status: 403
        return
      end
      changed_by = SuperSettings.configuration.controller.changed_by(self)
      result = SuperSettings::RestAPI.update(params[:settings], changed_by)
      if result[:success]
        render json: result
      else
        render json: result, status: 422
      end
    end

    # API endpoint for getting the history of a setting. See SuperSettings::RestAPI for details.
    def history
      setting_history = SuperSettings::RestAPI.history(params[:key], offset: params[:offset], limit: params[:limit])
      if setting_history
        render json: setting_history
      else
        render json: nil, status: 404
      end
    end

    # API endpoint for getting the last time a setting was changed. See SuperSettings::RestAPI for details.
    def last_updated_at
      render json: SuperSettings::RestAPI.last_updated_at
    end

    # API endpoint for getting settings that have changed since specified time. See SuperSettings::RestAPI for details.
    def updated_since
      render json: SuperSettings::RestAPI.updated_since(params[:time])
    end

    # API endpoint for checking if the user is authorized to edit settings.
    def authorized
      permission = super_settings_read_only? ? "read-only" : "read-write"
      headers["super-settings-permission"] = permission
      headers["cache-control"] = "no-cache"
      render json: {authorized: true, permission: permission}
    end

    # Serve up the api.js file that defines a JavaScript client for the REST API.
    def api_js
      js = File.read(File.expand_path(File.join("application", "api.js"), __dir__))
      render js: js.html_safe, content_type: "application/javascript; charset=utf-8"
    end

    protected

    # Mark the current request as read-only. When read-only, the web UI will hide edit
    # controls and write API endpoints will return 403. Call this in a +before_action+ to
    # restrict a user to read-only access.
    def super_settings_read_only!
      request.env["super_settings.read_only"] = true
    end

    # Return true if the current request has been marked as read-only.
    def super_settings_read_only?
      !!request.env["super_settings.read_only"]
    end

    # Return true if CSRF protection needs to be enabled for the request.
    # By default it is only enabled on stateful requests that include Basic authorization
    # or cookies in the request so that stateless REST API calls are allowed.
    def protect_from_forgery?
      return false if action_name == "api_js"

      request.cookies.present? || request.authorization.to_s.split(" ", 2).first&.match?(/\ABasic/i)
    end
  end
end
