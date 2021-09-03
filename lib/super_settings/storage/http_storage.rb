# frozen_string_literal: true

require "json"
require "net/http"

# SuperSettings::Storage model that reads from a remote service running the SuperSettings REST API.
# This storage engine is read only. It is intended to allow microservices to read settings from a
# central application that exposes the SuperSettings::RestAPI.
module SuperSettings
  module Storage
    class HttpStorage
      include Storage

      DEFAULT_HEADERS = {"Accept" => "application/json"}.freeze
      DEFAULT_TIMEOUT = 5.0

      attr_reader :key, :raw_value, :description, :value_type, :updated_at, :created_at

      class Error < StandardError
      end

      class NotFoundError < Error
      end

      class InvalidRecordError < Error
        attr_reader :errors

        def initialize(message, errors:)
          super(message)
          @errors = errors
        end
      end

      class HistoryStorage
        include SuperSettings::Attributes

        attr_accessor :key, :value, :changed_by, :deleted

        def created_at=(val)
          @created_at = SuperSettings::Coerce.time(val)
        end

        def deleted?
          !!(defined?(@deleted) && @deleted)
        end
      end

      class << self
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
          record.send(:set_persisted!)
          record
        rescue NotFoundError
          nil
        end

        def last_updated_at
          value = call_api(:get, "/settings/last_updated_at")["last_updated_at"]
          SuperSettings::Coerce.time(value)
        end

        attr_accessor :base_url

        attr_accessor :timeout

        def headers
          @headers ||= {}
        end

        def query_params
          @query_params ||= {}
        end

        protected

        def default_load_asynchronous?
          true
        end

        private

        def call_api(method, path, params = {})
          url_params = (method == :get ? query_params.merge(params) : query_params)
          uri = api_uri(path, url_params)

          body = nil
          request_headers = DEFAULT_HEADERS.merge(headers)
          if method == :post && !params&.empty?
            body = params.to_json
            request_headers["Content-Type"] = "application/json; charset=utf8-"
          end

          response = http_request(method: method, uri: uri, headers: request_headers, body: body)

          begin
            response.value # raises exception unless response is a success
            JSON.parse(response.body)
          rescue Net::ProtocolError
            if [404, 410].include?(response.code.to_i)
              raise NotFoundError.new("#{response.code} #{response.message}")
            elsif response.code.to_i == 422
              raise InvalidRecordError.new("#{response.code} #{response.message}", errors: JSON.parse(response.body)["errors"])
            else
              raise Error.new("#{response.code} #{response.message}")
            end
          rescue JSON::JSONError => e
            raise Error.new(e.message)
          end
        end

        def http_request(method:, uri:, headers: {}, body: nil, redirect_count: 0)
          response = nil
          http = Net::HTTP.new(uri.host, uri.port || uri.inferred_port)
          begin
            http.read_timeout = (timeout || DEFAULT_TIMEOUT)
            http.open_timeout = (timeout || DEFAULT_TIMEOUT)
            if uri.scheme == "https"
              http.use_ssl = true
              http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            end

            request = (method == :post ? Net::HTTP::Post.new(uri.request_uri) : Net::HTTP::Get.new(uri.request_uri))
            set_headers(request, headers)
            request.body = body if body

            response = http.request(request)
          ensure
            begin
              http.finish if http.started?
            rescue IOError
            end
          end

          if response.is_a?(Net::HTTPRedirection)
            location = resp["Location"]
            if redirect_count < 5 && SuperSettings::Coerce.present?(location)
              return http_request(method: :get, uri: URI(location), headers: headers, body: body, redirect_count: redirect_count + 1)
            end
          end

          response
        end

        def api_uri(path, params)
          uri = URI("#{base_url.chomp("/")}#{path}")
          if params && !params.empty?
            q = []
            q << uri.query unless uri.query.to_s.empty?
            params.each do |name, value|
              q << "#{URI.encode_www_form_component(name.to_s)}=#{URI.encode_www_form_component(value.to_s)}"
            end
            uri.query = q.join("&")
          end
          uri
        end

        def set_headers(request, headers)
          headers.each do |name, value|
            name = name.to_s
            values = Array(value)
            request[name] = values[0].to_s
            values[1, values.length].each do |val|
              request.add_field(name, val.to_s)
            end
          end
        end
      end

      def save!
        payload = {key: key}
        if deleted?
          payload[:deleted] = true
        else
          payload[:value] = value
          payload[:value_type] = value_type
          payload[:description] = description
        end

        begin
          call_api(:post, "/settings", settings: [payload])
          set_persisted!
        rescue InvalidRecordError
          return false
        end
        true
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

      def create_history(changed_by:, created_at:, value: nil, deleted: false)
        # No-op since history is maintained by the source system.
      end

      def reload
        self.class.find_by_key(key)
        self.attributes = self.class.find_by_key(key).attributes
        self
      end

      def key=(value)
        @key = (Coerce.blank?(value) ? nil : value.to_s)
      end

      def raw_value=(value)
        @raw_value = (Coerce.blank?(value) ? nil : value.to_s)
      end
      alias_method :value=, :raw_value=
      alias_method :value, :raw_value

      def value_type=(value)
        @value_type = (Coerce.blank?(value) ? nil : value.to_s)
      end

      def description=(value)
        @description = (Coerce.blank?(value) ? nil : value.to_s)
      end

      def deleted=(value)
        @deleted = Coerce.boolean(value)
      end

      def created_at=(value)
        @created_at = SuperSettings::Coerce.time(value)
      end

      def updated_at=(value)
        @updated_at = SuperSettings::Coerce.time(value)
      end

      def deleted?
        !!(defined?(@deleted) && @deleted)
      end

      def persisted?
        !!(defined?(@persisted) && @persisted)
      end

      protected

      def redact_history!
        # No-op since history is maintained by the source system.
      end

      private

      def set_persisted!
        @persisted = true
      end

      def call_api(method, path, params = {})
        self.class.send(:call_api, method, path, params)
      end

      def encrypted=(value)
        # No op; needed for API compatibility
      end
    end
  end
end
