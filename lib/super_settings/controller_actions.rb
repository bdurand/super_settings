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

    HISTORY_PAGE_SIZE = 25

    included do
      layout "super_settings/settings"
      helper SettingsHelper
    end

    # Get all settings sorted by key. This endpoint may be called with a REST GET request.
    # The response payload is:
    # [
    #   {
    #     id: integer,
    #     key: string,
    #     value: object,
    #     value_type: string,
    #     description string,
    #     created_at: iso8601 string,
    #     updated_at: iso8601 string
    #   },
    #   ...
    # ]
    def index
      @settings = Setting.order(:key)
      respond_to do |format|
        format.json { render json: @settings.as_json }
        format.html { render :index }
      end
    end

    # Get a setting by id. This endpoint may be called with a REST GET request.
    # The response payload is:
    # {
    #   id: integer,
    #   key: string,
    #   value: object,
    #   value_type: string,
    #   description string,
    #   created_at: iso8601 string,
    #   updated_at: iso8601 string
    # }
    #
    # This also serves as the AJAX endpoint to render the partial to show the setting value.
    def show
      setting = Setting.find(params[:id])
      respond_to do |format|
        format.json { render json: setting.as_json }
        format.html { render partial: "super_settings/settings/setting", locals: {setting: setting} }
      end
    end

    # AJAX endpoint to get the edit form partial.
    def edit
      setting = Setting.find(params[:id])
      render partial: "super_settings/settings/edit_setting", locals: {setting: setting}
    end

    # AJAX endpoint to get the new form partial.
    def new
      render partial: "super_settings/settings/edit_setting", locals: {setting: Setting.new}
    end

    # The update operation uses a transaction to atomically update all settings.
    # This endpoint may be called with a REST POST request. The format of the parameters
    # is an array of hash with each setting identified by the key. The settings should include
    # either value and value type (and optionally description) to insert or update a setting, or
    # delete to delete the setting.
    # { settings: [
    #     {
    #       key: string,
    #       value: object,
    #       value_type: string,
    #       description: string,
    #     },
    #     {
    #       key: string,
    #       delete: boolean,
    #     },
    #     ...
    #   ]
    # }
    #
    # The REST response format is either {success: true} or {success: false, errors: [string, ...]}
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

    # Return the history of the setting. This endpoint may be called with a REST GET request.
    # The response format is:
    # [
    #   {
    #     key: string,
    #     value: object,
    #     changed_by: string,
    #     created_at: iso8601 string
    #   },
    #   ...
    # ]
    #
    # This also serves as the AJAX endpoint to render the setting history.
    def history
      @setting = Setting.find(params[:id])
      @histories = @setting.histories.order(id: :desc).limit(HISTORY_PAGE_SIZE).offset(params[:offset]).to_a
      @previous_offset = [params[:offset].to_i - HISTORY_PAGE_SIZE, 0].max if params[:offset].to_i > 0
      if @histories.size == HISTORY_PAGE_SIZE && @setting.histories.where("id > ?", @histories.last.id).exists?
        @next_offset = params[:offset].to_i + HISTORY_PAGE_SIZE
      end
      respond_to do |format|
        format.json { render json: @histories.as_json }
        format.html { render :history, layout: false }
      end
    end

    private

    # Update all settings in memory. Only if all settings are valid will the changes
    # actually be applied.
    def update_super_settings
      changed = {}
      changed_by = Configuration.instance.controller.changed_by(self)
      all_valid = true

      # Parameters are passed as a hash from the web page form, but can be passed as an array in REST.
      parameters = (params[:settings].respond_to?(:values) ? params[:settings].values : params[:settings])
      parameters.each do |setting_params|
        next if setting_params[:key].blank?
        next if setting_params[:value_type].blank? && setting_params[:delete].blank?

        setting = Setting.with_deleted.find_by(key: setting_params[:key])
        unless setting
          next if setting_params[:delete].present?
          setting = Setting.new(key: setting_params[:key])
        end

        if setting_params[:delete].present?
          setting.deleted = BooleanParser.cast(setting_params[:delete])
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
