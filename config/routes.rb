# frozen_string_literal: true

SuperSettings::Engine.routes.draw do

  controller :settings do
    get "", action: :index, as: :index
    post "", action: :update, as: :update
    get "new", action: :new, format: "html"
    get ":id", action: :show
    get ":id/edit", action: :edit, format: "html"
    get ":id/history", action: :history, as: :history
  end

end
