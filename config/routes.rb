# frozen_string_literal: true

SuperSettings::Engine.routes.draw do
  controller :settings do
    get "/", action: :index, as: :index
    post "/", action: :update, as: :update
    get "/setting", action: :show, format: "json"
    get "/history", action: :history, format: "json", as: :history
  end
end
