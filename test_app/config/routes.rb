# frozen_string_literal: true

Rails.application.routes.draw do
  root to: "root#index"

  mount SuperSettings::Engine => "/super_settings"

  controller :configurations do
    get "/configuration", action: :index
  end
end
