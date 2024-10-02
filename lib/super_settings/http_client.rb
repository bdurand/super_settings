# frozen_string_literal: true

require "net/http"
require "uri"

module SuperSettings
  # This is a simple HTTP client that is used to communicate with the REST API. It
  # will keep the connection alive and reuse it on subsequent requests.
  class HttpClient
    DEFAULT_HEADERS = {"Accept" => "application/json"}.freeze
    DEFAULT_TIMEOUT = 5.0
    KEEP_ALIVE_TIMEOUT = 60

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

    def initialize(base_url, headers: nil, params: nil, timeout: nil, user: nil, password: nil)
      base_url = "#{base_url}/" unless base_url.end_with?("/")
      @base_uri = URI(base_url)
      @base_uri.query = query_string(params) if params
      @headers = headers ? DEFAULT_HEADERS.merge(headers) : DEFAULT_HEADERS
      @timeout = timeout || DEFAULT_TIMEOUT
      @user = user
      @password = password
      @mutex = Mutex.new
      @connections = []
    end

    def get(path, params = nil)
      request = Net::HTTP::Get.new(request_uri(path, params))
      send_request(request)
    end

    def post(path, params = nil)
      request = Net::HTTP::Post.new(request_uri(path))
      request.body = JSON.dump(params) if params
      send_request(request)
    end

    private

    def send_request(request)
      set_headers(request)
      response_payload = nil
      attempts = 0

      with_connection do |http|
        http.start unless http.started?
        response = http.request(request)

        begin
          response.value # raises exception unless response is a success
          response_payload = JSON.parse(response.body)
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
      rescue IOError, Errno::ECONNRESET => connection_error
        attempts += 1
        retry if attempts <= 1
        raise connection_error
      end

      response_payload
    end

    def with_connection(&block)
      http = pop_connection
      begin
        response = yield(http)
        return_connection(http)
        response
      rescue => e
        begin
          http.finish if http.started?
        rescue IOError
        end
        raise e
      end
    end

    def pop_connection
      http = nil
      @mutex.synchronize do
        http = @connections.pop
      end
      http = nil unless http&.started?
      http ||= new_connection
      http
    end

    def return_connection(http)
      @mutex.synchronize do
        if @connections.empty?
          @connections.push(http)
          http = nil
        end
      end

      if http
        begin
          http.finish if http.started?
        rescue IOError
        end
      end
    end

    def new_connection
      http = Net::HTTP.new(@base_uri.host, @base_uri.port || @base_uri.inferred_port)
      http.use_ssl = @base_uri.scheme == "https"
      http.open_timeout = @timeout
      http.read_timeout = @timeout
      http.write_timeout = @timeout
      http.keep_alive_timeout = KEEP_ALIVE_TIMEOUT
      http
    end

    def set_headers(request)
      @headers.each do |name, value|
        name = name.to_s
        values = Array(value)
        request[name] = values[0].to_s
        values[1, values.length].each do |val|
          request.add_field(name, val.to_s)
        end
      end
    end

    def request_uri(path, params = nil)
      uri = URI.join(@base_uri, path.delete_prefix("/"))
      if (params && !params.empty?) || (@base_uri.query && !@base_uri.query.empty?)
        uri.query = [uri.query, query_string(params)].join("&")
      end
      uri
    end

    def query_string(params)
      q = []
      q << @base_uri.query unless @base_uri.query.to_s.empty?
      params&.each do |name, value|
        q << "#{URI.encode_www_form_component(name.to_s)}=#{URI.encode_www_form_component(value.to_s)}"
      end
      q.join("&")
    end
  end
end
