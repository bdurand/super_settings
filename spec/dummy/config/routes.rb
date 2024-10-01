Rails.application.routes.draw do
  mount SuperSettings::Engine => "/settings"

  controller :bootstrap do
    get "/bootstrap", action: :index
  end
end
