module Dotypos
  # Builds the filter query string expected by the Dotypos API.
  #
  # API format:  "attribute|operator|value;attribute2|operator2|value2"
  # Supported operators: eq, ne, gt, gteq, lt, lteq, like, in, notin, bin, bex
  #
  # Usage (block DSL):
  #   filter = Dotypos::FilterBuilder.build do |f|
  #     f.where :price,   :gteq,  500
  #     f.where :deleted, :eq,    false
  #     f.where :name,    :like,  "John"
  #   end
  #   # => "price|gteq|500;deleted|eq|0;name|like|John"
  #
  # Usage (chainable):
  #   filter = Dotypos::FilterBuilder.new
  #     .where(:price, :gteq, 500)
  #     .where(:deleted, :eq, false)
  #     .to_s
  #
  # Pass the result to any list call:
  #   client.orders.list(filter: filter, sort: "-created")
  class FilterBuilder
    VALID_OPERATORS = %w[eq ne gt gteq lt lteq like in notin bin bex].freeze

    def self.build(&block)
      builder = new
      block.call(builder)
      builder.to_s
    end

    def initialize
      @conditions = []
    end

    # Adds a filter condition.
    #
    # @param attribute [Symbol, String] the API attribute name (snake_case is converted to camelCase)
    # @param operator  [Symbol, String] one of the supported operators
    # @param value     the filter value (booleans are converted to 1/0)
    # @return [self] for chaining
    def where(attribute, operator, value)
      op = operator.to_s.downcase
      unless VALID_OPERATORS.include?(op)
        raise ArgumentError, "Invalid filter operator '#{op}'. " \
                             "Valid operators: #{VALID_OPERATORS.join(', ')}"
      end

      api_attribute = KeyTransformer.camel_key(attribute)
      api_value     = serialize_value(value)

      @conditions << "#{api_attribute}|#{op}|#{api_value}"
      self
    end

    # Returns the encoded filter string or nil if no conditions were added.
    def to_s
      @conditions.empty? ? nil : @conditions.join(";")
    end

    def empty?
      @conditions.empty?
    end

    private

    def serialize_value(value)
      case value
      when true  then "1"
      when false then "0"
      when nil   then "null"
      when Array then value.map { |v| serialize_value(v) }.join(",")
      else value.to_s
      end
    end
  end
end
