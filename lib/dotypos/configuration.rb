module Dotypos
  class Configuration
    attr_accessor :timeout, :open_timeout, :logger

    API_BASE_URL = "https://api.dotykacka.cz/v2"

    def initialize
      @timeout      = 30
      @open_timeout = 5
      @logger       = nil
    end
  end
end
