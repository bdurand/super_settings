# frozen_string_literal: true

module SuperSettings
  # Base controller class for the engine. This can be overridden with the `controller.superclass`
  # value in the Configuration.
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
  end
end
