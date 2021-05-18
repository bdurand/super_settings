# frozen_string_literal: true

SuperSettings::Engine.routes.draw do
  controller :settings do
    get "/", action: :index, as: :index
    post "/", action: :update, as: :update
    get ":id", action: :show, format: "json"
    get ":id/edit", action: :edit, format: "json"
    get ":id/history", action: :history, format: "json", as: :history
  end
end
