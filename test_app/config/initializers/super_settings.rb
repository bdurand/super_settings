# frozen_string_literal: true

SuperSettings.configure do |config|
  config.controller.application_name = "Sample Application"
  config.controller.application_link = "/"
  config.controller.application_logo = "/images/logo.svg"

  config.controller.enhance do
    layout "application"
  end
end
