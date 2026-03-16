# frozen_string_literal: true

SuperSettings.configure do |config|
  config.controller.application_name = "Sample Application"
  config.controller.application_link = "/"
  config.controller.application_logo = "/images/logo.svg"

  config.controller.define_changed_by do
    "system user"
  end

  config.controller.enhance do
    layout "application"

    around_action do |controller, action|
      I18n.with_locale(current_locale) do
        action.call
      end
    end

    private

    def current_locale
      params[:lang]&.to_sym || I18n.locale
    end
  end
end
