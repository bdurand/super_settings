# frozen_string_literal: true

module SuperSettings
  module ControllerActions

    extend ActiveSupport::Concern

    included do
      layout "super_settings/settings"
      helper SuperSettings::SettingsHelper
    end

    def index
      @settings = SuperSettings::Setting.not_deleted.order(:key)
      render :index
    end

    def show
      setting = SuperSettings::Setting.find(params[:id])
      render partial: "super_settings/settings/setting", locals: {setting: setting}
    end

    def edit
      setting = SuperSettings::Setting.find(params[:id])
      render partial: "super_settings/settings/edit_setting", locals: {setting: setting}
    end

    def new
      render partial: "super_settings/settings/edit_setting", locals: {setting: SuperSettings::Setting.new}
    end

    def update
      all_valid, changed = update_settings
      if all_valid
        SuperSettings::Setting.transaction do
          changed.values.each do |setting|
            unless setting.save
              all_valid = false
              raise ActiveRecord::Rollback
            end
          end
        end
      end

      if all_valid
        flash[:notice] = "Settings saved"
        redirect_params = {}
        redirect_params[:filter] = params[:filter] if params[:filter].present?
        redirect_to super_settings.root_url(redirect_params)
      else
        @settings = all_settings_with_errors(changed)
        flash.now[:alert] = "Settings not saved"
        render :index, status: :unprocessable_entity
      end
    end

    private

    def update_settings
      changed = {}
      all_valid = true
      params[:settings].values.each do |setting_params|
        next if setting_params[:key].blank?
        next if setting_params[:value_type].blank? && setting_params[:_delete].blank?

        setting = SuperSettings::Setting.find_by(key: setting_params[:key])
        unless setting
          next if setting_params[:_delete].present?
          setting = SuperSettings::Setting.new(key: setting_params[:key])
        end

        if setting_params[:_delete].present?
          setting.deleted_at = Time.now
        elsif setting_params.include?(:value_type)
          setting.value_type = setting_params[:value_type]
          setting.value = (setting.boolean? ? setting_params[:value].present? : setting_params[:value])
          setting.deleted_at = nil if setting.deleted?
          all_valid &= setting.valid?
        end
        changed[setting.key] = setting
      end
      [all_valid, changed]
    end

    def all_settings_with_errors(changed)
      settings = changed.values.select(&:new_record?)
      SuperSettings::Setting.not_deleted.order(:key).each do |setting|
        if changed.include?(setting.key)
          settings << changed[setting.key]
        else
          settings << setting
        end
      end
      settings
    end

  end
end
