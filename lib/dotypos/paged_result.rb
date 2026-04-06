module Dotypos
  # Wraps a paginated list response from the API.
  #
  # The underlying API envelope (after snake_case conversion):
  #   current_page, per_page, total_items_on_page, total_items_count,
  #   first_page, last_page, next_page (number), prev_page (number)
  #
  # Usage:
  #   result = client.orders.list(page: 1, limit: 50)
  #   result.data           # => [Resource, Resource, ...]
  #   result.next_page?     # => true / false
  #   result.next_page      # => PagedResult (fetches page 2)
  #   result.prev_page?     # => true / false
  #   result.prev_page      # => PagedResult (fetches page 1)
  class PagedResult
    attr_reader :data,
                :current_page,
                :per_page,
                :total_items_on_page,
                :total_items_count,
                :first_page,
                :last_page

    def initialize(collection, envelope, request_params = {})
      @collection     = collection
      @request_params = request_params

      @data                = Array(envelope[:data]).map { |item| Resource.new(item) }
      @current_page        = envelope[:current_page]
      @per_page            = envelope[:per_page]
      @total_items_on_page = envelope[:total_items_on_page]
      @total_items_count   = envelope[:total_items_count]
      @first_page          = envelope[:first_page]
      @last_page           = envelope[:last_page]
      @next_page_number    = envelope[:next_page]
      @prev_page_number    = envelope[:prev_page]
    end

    # True when the API reports a next page exists.
    # For high-volume entities (orders, order-items) where next_page may be null,
    # we also check whether the current page is full.
    def next_page?
      if @next_page_number
        true
      elsif @per_page && @total_items_on_page
        @total_items_on_page >= @per_page
      else
        false
      end
    end

    # True when there is a previous page.
    def prev_page?
      @prev_page_number ? @prev_page_number >= 1 : (@current_page && @current_page > 1)
    end

    # Fetches and returns the next PagedResult, or nil if on the last page.
    def next_page
      return nil unless next_page?

      page_number = @next_page_number || (@current_page + 1)
      @collection.list(@request_params.merge(page: page_number))
    end

    # Fetches and returns the previous PagedResult, or nil if on the first page.
    def prev_page
      return nil unless prev_page?

      page_number = @prev_page_number || (@current_page - 1)
      @collection.list(@request_params.merge(page: page_number))
    end

    def inspect
      "#<#{self.class.name} page=#{current_page} items=#{data.size}" \
        " next=#{next_page?} prev=#{prev_page?}>"
    end
  end
end
