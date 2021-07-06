# frozen_string_literal: true

require "erb"

module SuperSettings
  # Module used to build the SuperSettings::Settings controller. This controller is defined
  # at runtime since it is assumed that the superclass will be one of the application's own
  # base controller classes since the application will want to define authentication and
  # authorization criteria.
  #
  # The controller is built by extending the class defined by the Configuration object and
  # then mixing in this module.
  module ControllerActions
    def self.included(base)
      base.layout "super_settings/settings"
      base.helper SettingsHelper
    end

    def root
      html = SuperSettings::Application.new.render("index.html.erb")
      render html: html.html_safe, layout: true
    end

    def index
      render json: SuperSettings::RestAPI.index
    end

    def show
      setting = SuperSettings::RestAPI.show(params[:key])
      if setting
        render json: setting
      else
        render json: nil, status: 404
      end
    end

    def update
      changed_by = Configuration.instance.controller.changed_by(self)
      result = SuperSettings::RestAPI.update(params[:settings], changed_by)
      if result[:success]
        render json: result
      else
        render json: result, status: 422
      end
    end

    def history
      setting_history = SuperSettings::RestAPI.history(params[:key], offset: params[:offset], limit: params[:limit])
      if setting_history
        render json: setting_history
      else
        render json: nil, status: 404
      end
    end

    def last_updated_at
      render json: SuperSettings::RestAPI.last_updated_at
    end

    def updated_since
      render json: SuperSettings::RestAPI.updated_since(params[:time])
    end
  end
end
