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
      html = SuperSettings::Application.new.render
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

    protected

    # Return true if CSRF protection needs to be enabled for the request.
    # By default it is only enabled on stateful requests that include Basic authorization
    # or cookies in the request so that stateless REST API calls are allowed.
    def protect_from_forgery?
      request.cookies.present? || request.authorization.to_s.split(" ", 2).first&.match?(/\ABasic/i)
    end
  end
end
