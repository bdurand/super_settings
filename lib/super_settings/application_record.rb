# frozen_string_literal: true

module SuperSettings
  # Base class that the models extend from.
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
