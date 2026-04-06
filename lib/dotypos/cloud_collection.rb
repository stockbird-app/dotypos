module Dotypos
  # Provides list and get operations for the Cloud resource.
  #
  # Clouds are top-level resources scoped to the refresh token, not to a single
  # cloud. Their paths do not follow the clouds/{cloudId}/{resource} pattern
  # used by ResourceCollection, so this subclass overrides the two path helpers.
  #
  # Usage:
  #   client.clouds.list          # => PagedResult of all accessible clouds
  #   client.clouds.get("123")    # => Resource for a specific cloud
  #   client.current_cloud        # => Resource for the client's own cloud
  class CloudCollection < ResourceCollection
    def initialize(client)
      super(client, nil)
    end

    private

    def collection_path
      "clouds"
    end

    def member_path(id)
      "clouds/#{id}"
    end
  end
end
