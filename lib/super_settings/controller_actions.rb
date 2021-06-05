# frozen_string_literal: true

module SuperSettings
  # Module used to build the SuperSettings::Settings controller. This controller is defined
  # at runtime since it is assumed that the superclass will be one of the application's own
  # base controller classes since the application will want to define authentication and
  # authorization criteria.
  #
  # The controller is built by extending the class defined by the Configuration object and
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
      @settings = Setting.active_settings.sort_by(&:key)
      respond_to do |format|
        format.json { render json: @settings.as_json }
        format.html { render :index }
      end
    end

    # Get a setting by id.
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
    def show
      setting = Setting.find_by_key(params[:key])
      if setting
        render json: setting.as_json
      else
        render json: nil, status: 404
      end
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
    # The REST response format is either {success: true} or {success: false, errors: {key => message, ...}}
    def update
      # Parameters are passed as a hash from the web page form, but can be passed as an array in REST.
      parameters = (params[:settings].respond_to?(:values) ? params[:settings].values : params[:settings]) || {}
      changed_by = Configuration.instance.controller.changed_by(self)

      all_valid, settings = Setting.bulk_update(parameters, changed_by)

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
            settings.each do |setting|
              if setting.errors.any?
                errors[setting.key] = setting.errors.full_messages
              end
            end
            render json: {success: false, errors: errors}, status: :unprocessable_entity
          end
          format.html do
            @changed_settings = settings.map do |setting|
              json = setting.as_json
              json[:errors] = setting.errors.full_messages if setting.errors.any?
              json[:new_record] = !setting.persisted?
              json
            end
            @settings = Setting.active_settings.sort_by(&:key)
            flash.now[:alert] = "Settings not saved"
            render :index, status: :unprocessable_entity
          end
        end
      end
    end

    # Return the history of the setting.
    # The response format is:
    # {
    #   key: string,
    #   histories: [
    #     {
    #       key: string,
    #       value: object,
    #       changed_by: string,
    #       created_at: iso8601 string
    #     },
    #     ...
    #   ]
    # }
    def history
      @setting = Setting.find_by_key(params[:key])
      page = params[:page].to_i
      page = 1 if page < 1
      offset = HISTORY_PAGE_SIZE * (page - 1)
      @histories = @setting.history(limit: HISTORY_PAGE_SIZE + 1, offset: offset)

      unless @histories.empty?
        if page > 1
          @previous_page_url = super_settings.history_url(id: @setting.id, page: (page > 2 ? page - 1 : nil))
        end
        if @histories.size > HISTORY_PAGE_SIZE
          @histories = @histories.take(HISTORY_PAGE_SIZE)
          @next_page_url = super_settings.history_url(id: @setting.id, page: page + 1)
        end
      end

      payload = {key: @setting.key}
      payload[:histories] = @histories.collect do |history|
        {value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}
      end
      payload[:previous_page_url] = @previous_page_url if @previous_page_url
      payload[:next_page_url] = @next_page_url if @next_page_url
      render json: payload
    end
  end
end
