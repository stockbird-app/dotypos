module Dotypos
  # Base error — callers can rescue Dotypos::Error to catch everything
  class Error < StandardError
    attr_reader :http_status, :http_body, :http_headers

    def initialize(msg = nil, http_status: nil, http_body: nil, http_headers: nil)
      super(msg)
      @http_status  = http_status
      @http_body    = http_body
      @http_headers = http_headers
    end

    def to_s
      http_status ? "(HTTP #{http_status}) #{super}" : super
    end
  end

  # Network-level errors
  class ConnectionError < Error; end
  class TimeoutError    < Error; end

  # 4xx client errors
  class ClientError         < Error; end
  class AuthenticationError < ClientError; end  # 401
  class ForbiddenError      < ClientError; end  # 403
  class NotFoundError       < ClientError; end  # 404
  class ConflictError       < ClientError; end  # 409 — versionDate mismatch
  class PreconditionError   < ClientError; end  # 412 — ETag mismatch on PUT/PATCH
  class UnprocessableError  < ClientError; end  # 422
  class RateLimitError      < ClientError; end  # 429

  # 5xx server errors
  class ServerError < Error; end
end
