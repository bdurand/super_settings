# frozen_string_literal: true

SuperSettings::Engine.routes.draw do
  controller :settings do
    get "/", action: :index, as: :index
    post "/", action: :update, as: :update
    get "/setting", action: :show, format: "json"
    get "/history", action: :history, format: "json"
    get "/last_updated_at", action: :last_updated_at, format: "json"
    get "/updated_since", action: :updated_since, format: "json"
  end
end
