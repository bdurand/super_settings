# frozen_string_literal: true

module SuperSettings
  module Storage
    # SuperSettings::Storage model that reads from a remote service running the SuperSettings REST API.
    # This storage engine is read only. It is intended to allow microservices to read settings from a
    # central application that exposes the SuperSettings::RestAPI.
    #
    # You must the the base_url class attribute to the base URL of a SuperSettings REST API endpoint.
    # You can also set the timeout, headers, and query_params used in reqeusts to the API.
    class HttpStorage < StorageAttributes
      include Storage
      include Transaction

      DEFAULT_HEADERS = {"Accept" => "application/json"}.freeze
      DEFAULT_TIMEOUT = 5.0

      @base_url = nil
      @timeout = nil
      @headers = {}
      @query_params = {}
      @http_client = nil
      @http_client_hash = nil

      class HistoryStorage < HistoryAttributes
      end

      class << self
        # Set the base URL for the SuperSettings REST API.
        attr_accessor :base_url

        # Set the timeout for requests to the SuperSettings REST API.
        attr_accessor :timeout

        # Add headers to this hash to add them to all requests to the SuperSettings REST API.
        #
        # @example
        #
        # SuperSettings::HttpStorage.headers["Authorization"] = "Bearer 12345"
        attr_reader :headers

        # Add query parameters to this hash to add them to all requests to the SuperSettings REST API.
        #
        # @example
        #
        # SuperSettings::HttpStorage.query_params["access_token"] = "12345"
        attr_reader :query_params

        def all
          call_api(:get, "/settings")["settings"].collect do |attributes|
            new(attributes)
          end
        end

        def updated_since(time)
          call_api(:get, "/settings/updated_since", time: time)["settings"].collect do |attributes|
            new(attributes)
          end
        end

        def find_by_key(key)
          record = new(call_api(:get, "/setting", key: key))
          record.persisted = true
          record
        rescue HttpClient::NotFoundError
          nil
        end

        def last_updated_at
          value = call_api(:get, "/settings/last_updated_at")["last_updated_at"]
          SuperSettings::Coerce.time(value)
        end

        def create_history(key:, changed_by:, created_at:, value: nil, deleted: false)
          # No-op since history is maintained by the source system.
        end

        def save_all(changes)
          payload = []
          changes.each do |setting|
            setting_payload = {key: setting.key}

            if setting.deleted?
              setting_payload[:deleted] = true
            else
              setting_payload[:value] = setting.value
              setting_payload[:value_type] = setting.value_type
              setting_payload[:description] = setting.description
            end

            payload << setting_payload
          end

          begin
            call_api(:post, "/settings", settings: payload)
          rescue HttpClient::InvalidRecordError
            return false
          end

          true
        end

        protected

        def default_load_asynchronous?
          true
        end

        private

        def call_api(method, path, params = {})
          if method == :post
            http_client.post(path, params)
          else
            http_client.get(path, params)
          end
        end

        def http_client
          hash = [base_url, timeout, headers, query_params].hash
          if @http_client.nil? || @http_client_hash != hash
            @http_client = HttpClient.new(base_url, headers: headers, params: query_params, timeout: timeout)
            @http_client_hash = hash
          end
          @http_client
        end
      end

      def history(limit: nil, offset: 0)
        params = {key: key}
        params[:offset] = offset if offset > 0
        params[:limit] = limit if limit
        history = call_api(:get, "/setting/history", params)
        history["histories"].collect do |attributes|
          HistoryItem.new(key: key, value: attributes["value"], changed_by: attributes["changed_by"], created_at: attributes["created_at"], deleted: attributes["deleted"])
        end
      end

      def reload
        self.class.find_by_key(key)
        self.attributes = self.class.find_by_key(key).attributes
        self
      end

      alias_method :value=, :raw_value=
      alias_method :value, :raw_value

      private

      def call_api(method, path, params = {})
        self.class.send(:call_api, method, path, params)
      end
    end
  end
end
