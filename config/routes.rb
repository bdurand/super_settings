# frozen_string_literal: true

SuperSettings::Engine.routes.draw do

  root controller: :settings, action: :index

  controller :settings do
    post "settings", action: :update, as: :update
    get "settings/show/:id", action: :show
    get "settings/edit/:id", action: :edit
    get "settings/new", action: :new
  end

end
