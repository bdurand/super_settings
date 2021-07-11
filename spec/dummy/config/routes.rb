Rails.application.routes.draw do
  mount SuperSettings::Engine => "/settings"
end
