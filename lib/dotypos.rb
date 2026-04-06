require_relative "dotypos/version"
require_relative "dotypos/errors"
require_relative "dotypos/configuration"
require_relative "dotypos/key_transformer"
require_relative "dotypos/token_manager"
require_relative "dotypos/resource"
require_relative "dotypos/paged_result"
require_relative "dotypos/filter_builder"
require_relative "dotypos/resource_collection"
require_relative "dotypos/cloud_collection"
require_relative "dotypos/client"

module Dotypos
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def reset!
      @configuration = Configuration.new
    end
  end
end
