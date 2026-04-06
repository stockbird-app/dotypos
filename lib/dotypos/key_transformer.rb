module Dotypos
  # Bidirectional key transformation between the API's lowerCamelCase / _prefixed
  # format and Ruby's conventional snake_case.
  #
  # API → Ruby (responses):
  #   "currentPage"  → :current_page
  #   "_cloudId"     → :cloud_id   (leading underscore stripped)
  #   "totalItemsCount" → :total_items_count
  #
  # Ruby → API (request bodies):
  #   :current_page      → "currentPage"
  #   :cloud_id          → "cloudId"   (no underscore prefix re-added; see note below)
  #
  # Note: The API's _-prefixed keys (like _cloudId) appear in entity bodies as
  # read-only metadata fields. When writing, cloudId is supplied via the URL path,
  # not the request body, so the round-trip loss of the leading _ is harmless.
  module KeyTransformer
    module_function

    # Recursively transform all keys in a Hash (or Array of Hashes) from the API
    # format to snake_case symbols.
    def to_snake(obj)
      case obj
      when Hash
        obj.transform_keys { |k| snake_key(k) }
           .transform_values { |v| to_snake(v) }
      when Array
        obj.map { |v| to_snake(v) }
      else
        obj
      end
    end

    # Recursively transform all keys in a Hash (or Array of Hashes) from
    # snake_case symbols/strings to lowerCamelCase strings for API requests.
    def to_camel(obj)
      case obj
      when Hash
        obj.transform_keys { |k| camel_key(k) }
           .transform_values { |v| to_camel(v) }
      when Array
        obj.map { |v| to_camel(v) }
      else
        obj
      end
    end

    # Single key: API string → snake_case symbol
    def snake_key(key)
      key.to_s
         .delete_prefix("_")       # strip leading underscore (_cloudId → cloudId)
         .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')  # ABCDef → ABC_def
         .gsub(/([a-z\d])([A-Z])/, '\1_\2')       # camelCase → camel_case
         .downcase
         .to_sym
    end

    # Single key: snake_case symbol/string → lowerCamelCase string
    def camel_key(key)
      parts = key.to_s.split("_")
      parts[0] + parts[1..].map(&:capitalize).join
    end
  end
end
