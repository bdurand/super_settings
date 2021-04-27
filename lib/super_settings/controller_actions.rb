# frozen_string_literal: true

module SuperSettings
  # Module used to build the SuperSettings::Settings controller. This controller is defined
  # at runtime since it is assumed that the superclass will be one of the application's own
  # base controller classes since the application will want to define authentication and
  # authorization criteria.
  #
  # The controller is built by extending the class defined by the Configuration objecgt and
  # then mixing in this module.
  module ControllerActions
    extend ActiveSupport::Concern

    included do
      layout "super_settings/settings"
      helper SettingsHelper
    end

    def index
      @settings = Setting.order(:key)
      respond_to do |format|
        format.json { render json: @settings.as_json }
        format.html { render :index }
      end
    end

    def show
      setting = Setting.find(params[:id])
      respond_to do |format|
        format.json { render json: setting.as_json }
        format.html { render partial: "super_settings/settings/setting", locals: {setting: setting} }
      end
    end

    def edit
      setting = Setting.find(params[:id])
      render partial: "super_settings/settings/edit_setting", locals: {setting: setting}
    end

    def new
      render partial: "super_settings/settings/edit_setting", locals: {setting: Setting.new}
    end

    # The update operation uses a transaction to atomically update all settings at once.
    def update
      all_valid, changed = update_super_settings
      if all_valid
        Setting.transaction do
          changed.values.each do |setting|
            unless setting.save
              all_valid = false
              raise ActiveRecord::Rollback
            end
          end
        end
      end

      if all_valid
        respond_to do |format|
          format.json { render json: {success: true} }
          format.html do
            flash[:notice] = "Settings saved"
            redirect_params = {}
            redirect_params[:filter] = params[:filter] if params[:filter].present?
            redirect_to super_settings.index_url(redirect_params)
          end
        end
      else
        respond_to do |format|
          format.json do
            errors = {}
            changed.each do |setting|
              if setting.errors.any?
                errors[setting[key]] = setting.errors.full_messages
              end
            end
            render json: {success: false, errors: errors}, status: :unprocessable_entity
          end
          format.html do
            @settings = all_super_settings_with_errors(changed)
            flash.now[:alert] = "Settings not saved"
            render :index, status: :unprocessable_entity
          end
        end
      end
    end

    def history
      @setting = Setting.find(params[:id])
      @histories = @setting.histories.order(id: :desc).limit(50).offset(params[:offset])
      respond_to do |format|
        format.json { render json: @histories.as_json }
        format.html { render :history }
      end
    end

    private

    # Update all settings in memory. Only if all settings are valid will the changes
    # actually be applied.
    def update_super_settings
      changed = {}
      changed_by = Configuration.instance.controller.changed_by(self)
      all_valid = true
      params[:settings].values.each do |setting_params|
        next if setting_params[:key].blank?
        next if setting_params[:value_type].blank? && setting_params[:_delete].blank?

        setting = Setting.with_deleted.find_by(key: setting_params[:key])
        unless setting
          next if setting_params[:_delete].present?
          setting = Setting.new(key: setting_params[:key])
        end

        if setting_params[:_delete].present?
          setting.deleted = true
          setting.changed_by = changed_by
        elsif setting_params.include?(:value_type)
          setting.value_type = setting_params[:value_type]
          setting.value = (setting.boolean? ? setting_params[:value].present? : setting_params[:value])
          setting.description = setting_params[:description] if setting_params.include?(:description)
          setting.deleted = false if setting.deleted?
          setting.changed_by = changed_by
          all_valid &= setting.valid?
        end
        changed[setting.key] = setting
      end
      [all_valid, changed]
    end

    # This method is used when there are errors saving changes. It loads all the settings,
    # but makes sure any ones being upated are mixed in so that errors on the models can be
    # displayed in the view.
    def all_super_settings_with_errors(changed)
      settings = changed.values.select(&:new_record?)
      Setting.order(:key).each do |setting|
        settings << if changed.include?(setting.key)
          changed[setting.key]
        else
          setting
        end
      end
      settings
    end
  end
end
