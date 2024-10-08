# frozen_string_literal: true

SuperSettings::Engine.routes.draw do
  controller :settings do
    if SuperSettings.configuration.controller.web_ui_enabled?
      get "/", action: :root, as: :root
    end
    get "/settings", action: :index
    post "/settings", action: :update
    get "/setting", action: :show
    get "/setting/history", action: :history
    get "/settings/last_updated_at", action: :last_updated_at
    get "/settings/updated_since", action: :updated_since
  end
end
