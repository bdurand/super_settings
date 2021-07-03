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

    included do
      layout "super_settings/settings"
      helper SettingsHelper
    end

    # Get all settings sorted by key. This endpoint may be called with a REST GET request.
    #
    # `GET /`
    #
    # The response payload is:
    # ```
    # [
    #   {
    #     key: string,
    #     value: object,
    #     value_type: string,
    #     description string,
    #     created_at: iso8601 string,
    #     updated_at: iso8601 string
    #   },
    #   ...
    # ]
    # ```
    def index
      @settings = Setting.active_settings.sort_by(&:key)
      respond_to do |format|
        format.json { render json: @settings.as_json }
        format.html { render :index }
      end
    end

    # Get a setting by id.
    #
    # `GET /setting`
    #
    # Query parameters
    #
    # * key - setting key
    #
    # The response payload is:
    # ```
    # {
    #   key: string,
    #   value: object,
    #   value_type: string,
    #   description string,
    #   created_at: iso8601 string,
    #   updated_at: iso8601 string
    # }
    # ```
    def show
      setting = Setting.find_by_key(params[:key])
      if setting
        render json: setting.as_json
      else
        render json: nil, status: 404
      end
    end

    # The update operation uses a transaction to atomically update all settings.
    #
    # `POST /settings`
    #
    # The format of the parameters is an array of hashes with each setting identified by the key.
    # The settings should include either `value` and `value_type` (and optionally `description`) to
    # insert or update a setting, or `delete` to delete the setting.
    #
    # ```
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
    # ```
    #
    # The response will be either `{success: true}` or `{success: false, errors: {key => message, ...}}`
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
            @changed_settings = settings.collect do |setting|
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
    #
    # `GET /setting/history`
    #
    # Query parameters
    #
    # * key - setting key
    # * limit - number of history items to return
    # * offset - index to start fetching items from (most recent items are first)
    #
    # The response format is:
    # ```
    # {
    #   key: string,
    #   histories: [
    #     {
    #       value: object,
    #       changed_by: string,
    #       created_at: iso8601 string
    #     },
    #     ...
    #   ],
    #   previous_page_url: string,
    #   next_page_url: string
    # }
    # ```
    def history
      setting = Setting.find_by_key(params[:key])
      offset = [params[:offset].to_i, 0].max
      limit = params[:limit].to_i
      fetch_limit = (limit > 0 ? limit + 1 : nil)
      histories = setting.history(limit: fetch_limit, offset: offset)

      if limit > 0 && !histories.empty?
        if offset > 0
          previous_page_url = super_settings.history_url(key: setting.key, offset: [offset - limit, 0].max, limit: limit)
        end
        if histories.size > limit
          histories = histories.take(limit)
          next_page_url = super_settings.history_url(key: setting.key, offset: offset + limit, limit: limit)
        end
      end

      payload = {key: setting.key}
      payload[:histories] = histories.collect do |history|
        history_values = {value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}
        history_values[:deleted] = true if history.deleted?
        history_values
      end
      payload[:previous_page_url] = previous_page_url if previous_page_url
      payload[:next_page_url] = next_page_url if next_page_url
      render json: payload
    end

    # Return the timestamp of the most recently updated setting.
    #
    # `GET /last_updated_at`
    #    #
    # The response payload is:
    # {
    #   last_updated_at: iso8601 string
    # }
    def last_updated_at
      render json: {last_updated_at: Setting.last_updated_at.utc.iso8601}
    end

    # Return settings that have been updated since a specified timestamp.
    #
    # `GET /updated_since`
    #
    # Query parameters
    #
    # * time - iso8601 string
    #
    # The response payload is:
    # ```
    # [
    #   {
    #     key: string,
    #     value: object,
    #     value_type: string,
    #     description string,
    #     created_at: iso8601 string,
    #     updated_at: iso8601 string
    #   },
    #   ...
    # ]
    # ```
    def updated_since
      settings = Setting.updated_since(params[:time])
      render json: settings.as_json
    end
  end
end
