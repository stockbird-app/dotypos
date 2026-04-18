module Dotypos
  # Provides CRUD operations for a single API resource type.
  #
  # All methods are reached via the client accessors:
  #   client.orders         # => ResourceCollection scoped to "order"
  #   client.products       # => ResourceCollection scoped to "product"
  #
  # List
  #   result = client.orders.list(page: 1, limit: 50, filter: "...", sort: "-created")
  #   # => PagedResult
  #
  # Get single
  #   order = client.orders.get("123456789")
  #   # => Resource (with ETag set)
  #
  # Create
  #   order = client.orders.create(note: "Table 4", table_id: "987")
  #   # => Resource
  #
  # Update (PATCH — partial, requires ETag)
  #   # Pass the Resource object — ETag is used automatically:
  #   updated = client.orders.update(order, note: "Table 5")
  #   # Or pass id + attrs + explicit etag:
  #   updated = client.orders.update("123", { note: "Table 5" }, etag: "abc123")
  #
  # Replace (PUT — full replace, requires ETag)
  #   replaced = client.orders.replace(order, full_attributes_hash)
  #   replaced = client.orders.replace("123", full_attributes_hash, etag: "abc123")
  #
  # Delete
  #   client.orders.delete("123456789")   # => true
  class ResourceCollection
    def initialize(client, path)
      @client = client
      @path   = path
    end

    # Returns a PagedResult.
    #
    # @param params [Hash] query parameters: page:, limit:, filter:, sort:, include:
    #   filter can be a String (raw API filter) or a FilterBuilder instance.
    #   include accepts a Symbol, String, or Array of either, and is converted to a
    #   camelCase comma-separated string for the API. Currently only meaningful for
    #   the orders endpoint; supported values per the API docs:
    #     :order_items  – embed order items inside each order
    #     :money_logs   – embed money logs inside each order
    #   Examples:
    #     client.orders.list(include: :order_items)
    #     client.orders.list(include: [:order_items, :money_logs])
    def list(params = {})
      params = normalize_list_params(params)
      # BC1 header makes the API return 200 + empty pagination JSON when no
      # results exist, instead of the default BC0 behaviour of returning 404.
      response = @client.request(:get, collection_path, params: params,
                                                        headers: { "Allow-Version" => "BC1" })
      envelope = KeyTransformer.to_snake(response.fetch(:body))
      PagedResult.new(self, envelope, params)
    end

    # Returns a single Resource with its ETag populated.
    def get(id)
      response = @client.request(:get, member_path(id))
      Resource.new(response.fetch(:body), etag: response[:etag])
    end

    # Creates one or more resources. Pass a Hash for a single resource or an
    # Array of Hashes for batch creation.
    # Returns a Resource (single) or Array<Resource> (batch).
    def create(attributes)
      body     = KeyTransformer.to_camel(attributes)
      response = @client.request(:post, collection_path, body: body)

      if response[:body].is_a?(Array)
        response[:body].map { |item| Resource.new(item) }
      else
        Resource.new(response.fetch(:body), etag: response[:etag])
      end
    end

    # Partial update (PATCH). Requires the current ETag.
    #
    # @overload update(resource, attributes = {})
    #   @param resource   [Resource] existing resource (ETag extracted automatically)
    #   @param attributes [Hash]     fields to update; merged with resource data when empty
    #
    # @overload update(id, attributes, etag: "...")
    #   @param id         [String]  entity ID
    #   @param attributes [Hash]    fields to update
    #   @param options    [Hash]    accepts :etag — current ETag from a prior GET
    def update(resource_or_id, attributes = {}, options = {})
      id, attrs, tag = resolve_mutation_args(resource_or_id, attributes, options[:etag])
      body     = KeyTransformer.to_camel(attrs.merge(id: id))
      response = @client.request(:patch, member_path(id), body: body,
                                                          headers: { "If-Match" => tag })
      Resource.new(response.fetch(:body), etag: response[:etag])
    end

    # Full replace (PUT). Requires the current ETag.
    #
    # @overload replace(resource, attributes = {})
    # @overload replace(id, attributes, etag: "...")
    def replace(resource_or_id, attributes = {}, options = {})
      id, attrs, tag = resolve_mutation_args(resource_or_id, attributes, options[:etag])
      body     = KeyTransformer.to_camel(attrs.merge(id: id))
      response = @client.request(:put, member_path(id), body: body,
                                                        headers: { "If-Match" => tag })
      Resource.new(response.fetch(:body), etag: response[:etag])
    end

    # Deletes the resource with the given id. Returns true on success.
    def delete(id)
      @client.request(:delete, member_path(id))
      true
    end

    private

    def collection_path
      "clouds/#{@client.cloud_id}/#{@path}"
    end

    def member_path(id)
      "clouds/#{@client.cloud_id}/#{@path}/#{id}"
    end

    def resolve_mutation_args(resource_or_id, attributes, explicit_etag)
      id, attrs, tag = if resource_or_id.is_a?(Resource)
                         args_from_resource(resource_or_id, attributes, explicit_etag)
                       else
                         [resource_or_id.to_s, attributes, explicit_etag]
                       end

      raise ArgumentError, etag_required_message if tag.nil?

      [id, attrs, tag]
    end

    def args_from_resource(resource, attributes, explicit_etag)
      id    = resource[:id].to_s
      attrs = attributes.empty? ? resource.to_h : attributes
      tag   = explicit_etag || resource.etag
      [id, attrs, tag]
    end

    def etag_required_message
      "An ETag is required for PUT/PATCH. Obtain one via #get first, " \
        "then pass the Resource object or supply etag: explicitly."
    end

    def normalize_list_params(params)
      params = params.merge(filter: params[:filter].to_s) if params[:filter].is_a?(FilterBuilder)
      params = params.merge(include: normalize_include(params[:include])) if params.key?(:include)
      params.compact
    end

    def normalize_include(value)
      return nil if value.nil?

      Array(value).map { |v| KeyTransformer.camel_key(v) }.join(",")
    end
  end
end
