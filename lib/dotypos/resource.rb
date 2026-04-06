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
    attr_accessor :etag

    def initialize(attributes, etag: nil)
      @attributes = KeyTransformer.to_snake(attributes)
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

    def deep_dup(obj)
      case obj
      when Hash  then obj.transform_values { |v| deep_dup(v) }
      when Array then obj.map { |v| deep_dup(v) }
      else obj
      end
    end
  end
end
