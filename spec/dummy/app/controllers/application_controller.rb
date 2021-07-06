# frozen_string_literal: true

class ApplicationController < ActionController::Base
  before_action do
    logger.debug("Overridden controller base")
  end
end
