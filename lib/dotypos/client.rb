require "faraday"
require "json"

module Dotypos
  # Entry point for all API interactions.
  #
  # Usage:
  #   client = Dotypos::Client.new(
  #     refresh_token: "your_refresh_token",
  #     cloud_id:      "123456"
  #   )
  #
  #   # List resources
  #   result = client.orders.list(page: 1, limit: 25)
  #   result.data.each { |order| puts order.id }
  #
  #   # Paginate
  #   next_result = result.next_page if result.next_page?
  #
  #   # Filter with DSL
  #   filter = Dotypos::FilterBuilder.build { |f| f.where(:deleted, :eq, false) }
  #   client.products.list(filter: filter, sort: "-version_date")
  #
  #   # Full CRUD
  #   customer = client.customers.get("789")
  #   client.customers.update(customer, name: "New Name")
  class Client
    API_BASE_URL = "https://api.dotykacka.cz/v2/"

    # All supported resource types.
    # key   = Ruby method name (snake_case, plural)
    # value = API path segment (as used in /v2/clouds/:cloudId/<segment>)
    RESOURCES = {
      branches:     "branch",
      categories:   "category",
      courses:       "course",
      customers:    "customer",
      employees:    "employee",
      order_items:  "order-item",
      orders:       "order",
      points_logs:  "pointslog",
      printers:     "printer",
      products:     "product",
      reservations: "reservation",
      stock_logs:   "stocklog",
      suppliers:    "supplier",
      tags:         "tag",
      warehouses:   "warehouse",
      webhooks:     "webhook"
    }.freeze

    attr_reader :cloud_id

    # @param refresh_token [String]  long-lived token obtained via the Dotypos OAuth flow
    # @param cloud_id      [String]  cloud identifier for this installation
    # @param timeout       [Integer] read timeout in seconds (default: 30)
    # @param open_timeout  [Integer] connection timeout in seconds (default: 5)
    # @param logger        [Logger, nil] optional logger; receives request/response details
    def initialize(refresh_token:, cloud_id:, timeout: 30, open_timeout: 5, logger: nil)
      @cloud_id      = cloud_id.to_s
      @timeout       = timeout
      @open_timeout  = open_timeout
      @logger        = logger

      @token_manager = TokenManager.new(
        refresh_token: refresh_token,
        cloud_id:      @cloud_id,
        base_url:      API_BASE_URL,
        timeout:       timeout,
        open_timeout:  open_timeout
      )
    end

    # Dynamically define accessor methods for each resource type.
    RESOURCES.each do |method_name, path|
      define_method(method_name) { ResourceCollection.new(self, path) }
    end

    # Allows calling any arbitrary API path not in the RESOURCES list.
    #   client.resource("custom-entity").list
    def resource(path)
      ResourceCollection.new(self, path)
    end

    # Makes an authenticated HTTP request. Used internally by ResourceCollection.
    #
    # @param method  [Symbol]  :get, :post, :patch, :put, :delete
    # @param path    [String]  path relative to API_BASE_URL (e.g. "/clouds/123/order")
    # @param params  [Hash]    query parameters
    # @param body    [Hash, nil] request body (will be JSON-encoded)
    # @param headers [Hash]    additional request headers
    # @return [Hash] { body: parsed_response, etag: "..." }
    def request(method, path, params: {}, body: nil, headers: {})
      access_token = @token_manager.access_token
      response     = execute_request(method, path,
                                     params:  params,
                                     body:    body,
                                     headers: headers,
                                     token:   access_token)

      # Transparently retry once on 401 (token may have been invalidated server-side)
      if response.status == 401
        access_token = @token_manager.force_refresh!
        response     = execute_request(method, path,
                                       params:  params,
                                       body:    body,
                                       headers: headers,
                                       token:   access_token)
      end

      handle_response(response)
    end

    private

    def execute_request(method, path, params:, body:, headers:, token:)
      conn = connection
      conn.run_request(method, path, body ? body.to_json : nil, request_headers(token, headers)) do |req|
        req.params = params unless params.empty?
      end
    rescue Faraday::ConnectionFailed => e
      raise Dotypos::ConnectionError, e.message
    rescue Faraday::TimeoutError => e
      raise Dotypos::TimeoutError, e.message
    end

    def handle_response(response)
      body   = parse_body(response.body)
      etag   = response.headers["etag"] || response.headers["ETag"]

      case response.status
      when 200..299
        { body: body, etag: etag }
      when 304
        { body: nil, etag: etag }
      when 401
        raise Dotypos::AuthenticationError.new(
          error_message(body, "Authentication failed"),
          http_status: 401, http_body: response.body, http_headers: response.headers
        )
      when 403
        raise Dotypos::ForbiddenError.new(
          error_message(body, "Forbidden"),
          http_status: 403, http_body: response.body, http_headers: response.headers
        )
      when 404
        raise Dotypos::NotFoundError.new(
          error_message(body, "Resource not found"),
          http_status: 404, http_body: response.body, http_headers: response.headers
        )
      when 409
        raise Dotypos::ConflictError.new(
          error_message(body, "Conflict — versionDate mismatch"),
          http_status: 409, http_body: response.body, http_headers: response.headers
        )
      when 412
        raise Dotypos::PreconditionError.new(
          error_message(body, "ETag mismatch — resource was modified since last read"),
          http_status: 412, http_body: response.body, http_headers: response.headers
        )
      when 422
        raise Dotypos::UnprocessableError.new(
          error_message(body, "Unprocessable entity"),
          http_status: 422, http_body: response.body, http_headers: response.headers
        )
      when 429
        raise Dotypos::RateLimitError.new(
          "Rate limit exceeded",
          http_status: 429, http_body: response.body, http_headers: response.headers
        )
      when 500..599
        raise Dotypos::ServerError.new(
          error_message(body, "Server error"),
          http_status: response.status, http_body: response.body, http_headers: response.headers
        )
      else
        raise Dotypos::Error.new(
          "Unexpected response status #{response.status}",
          http_status: response.status, http_body: response.body
        )
      end
    end

    def connection
      @connection ||= Faraday.new(url: API_BASE_URL) do |f|
        f.options.timeout      = @timeout
        f.options.open_timeout = @open_timeout
        f.request :logger, @logger, headers: false, bodies: false if @logger
        f.adapter Faraday.default_adapter
      end
    end

    def request_headers(token, extra = {})
      {
        "Authorization" => "Bearer #{token}",
        "Content-Type"  => "application/json",
        "Accept"        => "application/json",
        "User-Agent"    => "dotypos-ruby/#{Dotypos::VERSION} ruby/#{RUBY_VERSION}"
      }.merge(extra)
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body, symbolize_names: false)
    rescue JSON::ParserError
      body
    end

    def error_message(parsed_body, fallback)
      return fallback unless parsed_body.is_a?(Hash)

      parsed_body["message"] || parsed_body["error"] || fallback
    end
  end
end
