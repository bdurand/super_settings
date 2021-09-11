# frozen_string_literal: true

require "erb"

module SuperSettings
  class RestAPI
    class << self
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
        settings = Setting.active.sort_by(&:key)
        {settings: settings.collect(&:as_json)}
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
      def show(key)
        Setting.find_by_key(key)&.as_json
      end

      # The update operation uses a transaction to atomically update all settings.
      #
      # `POST /settings`
      #
      # The format of the parameters is an array of hashes with each setting identified by the key.
      # The settings should include either `value` and `value_type` (and optionally `description`) to
      # insert or update a setting, or `deleted` to delete the setting.
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
      #       deleted: boolean,
      #     },
      #     ...
      #   ]
      # }
      # ```
      #
      # The response will be either `{success: true}` or `{success: false, errors: {key => [string], ...}}`
      def update(settings_params, changed_by = nil)
        all_valid, settings = Setting.bulk_update(Array(settings_params), changed_by)
        if all_valid
          {success: true}
        else
          errors = {}
          settings.each do |setting|
            if setting.errors.any?
              errors[setting.key] = setting.errors.values.flatten
            end
          end
          {success: false, errors: errors}
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
      #   encrypted: boolean,
      #   histories: [
      #     {
      #       value: object,
      #       changed_by: string,
      #       created_at: iso8601 string
      #     },
      #     ...
      #   ],
      #   previous_page_params: hash,
      #   next_page_params: hash
      # }
      # ```
      def history(key, limit: nil, offset: 0)
        setting = Setting.find_by_key(key)
        return nil unless setting

        offset = [offset.to_i, 0].max
        limit = limit.to_i
        fetch_limit = (limit > 0 ? limit + 1 : nil)
        histories = setting.history(limit: fetch_limit, offset: offset)

        payload = {key: setting.key, encrypted: setting.encrypted?}

        if limit > 0 && !histories.empty?
          if offset > 0
            previous_page_params = {key: setting.key, offset: [offset - limit, 0].max, limit: limit}
          end
          if histories.size > limit
            histories = histories.take(limit)
            next_page_params = {key: setting.key, offset: offset + limit, limit: limit}
          end
          payload[:previous_page_params] = previous_page_params if previous_page_params
          payload[:next_page_params] = next_page_params if next_page_params
        end

        payload[:histories] = histories.collect do |history|
          history_values = {value: history.value, changed_by: history.changed_by_display, created_at: history.created_at}
          history_values[:deleted] = true if history.deleted?
          history_values
        end

        payload
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
        {last_updated_at: Setting.last_updated_at.utc.iso8601}
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
      def updated_since(time)
        time = Coerce.time(time)
        settings = Setting.updated_since(time)
        {settings: settings.collect(&:as_json)}
      end
    end
  end
end
