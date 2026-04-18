module Dotypos
  # Generic response object representing any API entity (order, product, customer, …).
  #
  # All keys are snake_case symbols. Attribute access is available via:
  #   - Dot notation:   resource.total_price
  #   - Hash notation:  resource[:total_price]
  #   - Plain hash:     resource.to_h
  #
  # The ETag received from a GET response is stored on the object and is
  # automatically used by ResourceCollection#update and #replace.
  class Resource
    # Known nested collection keys that are wrapped as Resource instances when
    # returned by the API via the `include` query parameter.
    NESTED_COLLECTION_KEYS = %i[order_items money_logs].freeze

    attr_accessor :etag

    def initialize(attributes, etag: nil)
      @attributes = wrap_nested_collections(KeyTransformer.to_snake(attributes))
      @etag       = etag
    end

    # Hash-style access with either symbol or string key.
    def [](key)
      @attributes[KeyTransformer.snake_key(key)]
    end

    # Returns a plain snake_case-keyed hash (deep copy).
    def to_h
      deep_dup(@attributes)
    end

    def inspect
      "#<#{self.class.name} #{@attributes.inspect}>"
    end

    def to_s
      inspect
    end

    def ==(other)
      other.is_a?(Resource) && other.to_h == to_h
    end

    def respond_to_missing?(name, include_private = false)
      @attributes.key?(name) || super
    end

    def method_missing(name, *args)
      if @attributes.key?(name)
        @attributes[name]
      else
        super
      end
    end

    private

    def wrap_nested_collections(attrs)
      NESTED_COLLECTION_KEYS.each do |key|
        next unless attrs[key].is_a?(Array)

        attrs[key] = attrs[key].map { |item| item.is_a?(Hash) ? Resource.new(item) : item }
      end
      attrs
    end

    def deep_dup(obj)
      case obj
      when Resource then obj.to_h
      when Hash     then obj.transform_values { |v| deep_dup(v) }
      when Array    then obj.map { |v| deep_dup(v) }
      else obj
      end
    end
  end
end
