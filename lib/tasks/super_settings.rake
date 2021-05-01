# frozen_string_literal: true

namespace :super_settings do
  desc "Encrypt settings marked as secret" do
    SuperSettings::Setting.where(value_type: "secret").each do |setting|
      setting.raw_value_will_change! if setting.value
    end
  end
end
