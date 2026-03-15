# frozen_string_literal: true

Rails.application.routes.draw do
  mount SuperSettings::Engine => "/super_settings"
end
