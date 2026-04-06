require "faraday"
require "json"

module Dotypos
  # Manages obtaining and refreshing the short-lived access token.
  #
  # The Dotypos auth flow (Step 2 of the documented OAuth model):
  #   POST /v2/signin/token
  #   Authorization: User {refreshToken}
  #   Body: { "_cloudId": "123" }
  #   Response: { "accessToken": "eyJ0..." }
  #
  # Access tokens expire in ~1 hour. This class keeps the token in memory,
  # checks expiry before each use, and refreshes proactively (60 s buffer).
  # A Mutex ensures thread safety.
  class TokenManager
    TOKEN_EXPIRY_SECONDS = 3600
    EXPIRY_BUFFER_SECONDS = 60
    AUTH_ENDPOINT = "signin/token"

    def initialize(refresh_token:, cloud_id:, base_url:, open_timeout: 5, timeout: 30)
      @refresh_token = refresh_token
      @cloud_id      = cloud_id.to_s
      @base_url      = base_url
      @open_timeout  = open_timeout
      @timeout       = timeout
      @access_token  = nil
      @expires_at    = nil
      @mutex         = Mutex.new
    end

    # Returns a valid access token, refreshing if necessary.
    def access_token
      @mutex.synchronize do
        refresh! if token_expired?
        @access_token
      end
    end

    # Forces a token refresh regardless of expiry. Used when the server
    # returns 401 mid-session (e.g. token invalidated server-side).
    # Returns the new access token.
    def force_refresh!
      @mutex.synchronize do
        refresh!
        @access_token
      end
    end

    private

    def token_expired?
      @access_token.nil? ||
        @expires_at.nil? ||
        Time.now >= @expires_at - EXPIRY_BUFFER_SECONDS
    end

    def refresh!
      response = auth_connection.post(AUTH_ENDPOINT) do |req|
        req.headers["Authorization"] = "User #{@refresh_token}"
        req.headers["Content-Type"]  = "application/json"
        req.body = JSON.generate("_cloudId" => @cloud_id)
      end

      unless response.status == 200
        raise Dotypos::AuthenticationError.new(
          "Failed to obtain access token",
          http_status: response.status,
          http_body:   response.body
        )
      end

      parsed = JSON.parse(response.body)
      @access_token = parsed["accessToken"] || parsed["access_token"]

      if @access_token.nil?
        raise Dotypos::AuthenticationError.new(
          "No accessToken in auth response: #{response.body}"
        )
      end

      @expires_at = Time.now + TOKEN_EXPIRY_SECONDS
    end

    def auth_connection
      @auth_connection ||= Faraday.new(url: @base_url) do |f|
        f.options.open_timeout = @open_timeout
        f.options.timeout      = @timeout
        f.adapter Faraday.default_adapter
      end
    end
  end
end
