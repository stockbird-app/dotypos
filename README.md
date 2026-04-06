# dotypos

Ruby API client for the [Dotypos (Dotykačka) API v2](https://docs.api.dotypos.com/).

Handles OAuth token management, automatic token refresh, pagination, and full CRUD for all API resources. Built by [Stockbird](https://stockbird.app).

## Installation

Add to your Gemfile:

```ruby
gem "dotypos"
```

Or install directly:

```sh
gem install dotypos
```

## Requirements

- Ruby >= 3.3.0
- A Dotypos `refresh_token` and `cloud_id` obtained via the [Dotypos OAuth flow](https://docs.api.dotypos.com/)

## Quick start

```ruby
client = Dotypos::Client.new(
  refresh_token: ENV["DOTYPOS_REFRESH_TOKEN"],
  cloud_id:      ENV["DOTYPOS_CLOUD_ID"]
)

# List orders (returns a PagedResult)
result = client.orders.list(limit: 25)
result.data.each { |order| puts "#{order.id}: #{order.note}" }

# Paginate
while result.next_page?
  result = result.next_page
  result.data.each { |order| puts order.id }
end
```

## Authentication

The gem handles authentication automatically. You only need to supply a `refresh_token` and `cloud_id` once — the gem obtains a short-lived access token and refreshes it transparently before it expires (~1 hour). The access token is kept in memory; no persistence is needed.

## Resources

The following resource accessors are available on the client:

| Method | API path |
|---|---|
| `client.branches` | `branch` |
| `client.categories` | `category` |
| `client.courses` | `course` |
| `client.customers` | `customer` |
| `client.employees` | `employee` |
| `client.order_items` | `order-item` |
| `client.orders` | `order` |
| `client.points_logs` | `pointslog` |
| `client.printers` | `printer` |
| `client.products` | `product` |
| `client.reservations` | `reservation` |
| `client.stock_logs` | `stocklog` |
| `client.suppliers` | `supplier` |
| `client.tags` | `tag` |
| `client.warehouses` | `warehouse` |
| `client.webhooks` | `webhook` |

For any path not in the list above:

```ruby
client.resource("custom-entity").list
```

## CRUD operations

### List

```ruby
result = client.products.list(page: 1, limit: 50, sort: "-versionDate")
result.data          # => [Dotypos::Resource, ...]
result.current_page  # => 1
result.next_page?    # => true
result.next_page     # => PagedResult for page 2
result.prev_page?    # => false
```

### Filter DSL

```ruby
filter = Dotypos::FilterBuilder.build do |f|
  f.where :deleted,     :eq,   false
  f.where :total_price, :gteq, 100
  f.where :name,        :like, "coffee"
end

result = client.products.list(filter: filter, sort: "-version_date")
```

Supported operators: `eq`, `ne`, `gt`, `gteq`, `lt`, `lteq`, `like`, `in`, `notin`, `bin`, `bex`.

### Get single resource

```ruby
product = client.products.get("123456789")
product.name          # => "Espresso"
product.total_price   # => "3.50"
product.etag          # => '"5C6FEF0BAD91914172B353E157219626"' (for updates)
product[:name]        # hash-style access
product.to_h          # plain snake_case symbol-keyed hash
```

### Create

```ruby
product = client.products.create(
  name:        "Cappuccino",
  total_price: "4.20"
)

# Batch create
products = client.products.create([
  { name: "Espresso", total_price: "3.50" },
  { name: "Latte",    total_price: "4.80" }
])
```

### Update (PATCH)

Always fetch first to get the ETag, then update:

```ruby
product = client.products.get("123456789")
updated = client.products.update(product, name: "Double Espresso")

# Or with explicit ID + ETag:
updated = client.products.update("123456789", { name: "Double Espresso" }, etag: product.etag)
```

### Replace (PUT)

```ruby
product = client.products.get("123456789")
replaced = client.products.replace(product, product.to_h.merge(name: "New Name"))
```

### Delete

```ruby
client.products.delete("123456789")  # => true
```

## Response objects

All returned data is a `Dotypos::Resource` — a generic object backed by a snake_case symbol-keyed hash. Access attributes via dot notation, hash notation, or `to_h`:

```ruby
order.total_price     # dot notation
order[:total_price]   # symbol key
order["totalPrice"]   # camelCase string key (also works)
order.to_h            # plain hash
```

API keys are transformed as follows:
- `currentPage` → `:current_page`
- `_cloudId` → `:cloud_id` (leading underscore stripped)
- `totalItemsCount` → `:total_items_count`

## Error handling

All errors inherit from `Dotypos::Error` and carry `http_status`, `http_body`, and `http_headers`:

```ruby
begin
  client.orders.get("nonexistent")
rescue Dotypos::NotFoundError => e
  puts e.http_status  # 404
rescue Dotypos::AuthenticationError
  # refresh_token invalid or revoked
rescue Dotypos::PreconditionError
  # ETag mismatch — resource was modified since last GET
rescue Dotypos::RateLimitError
  # 429 — back off and retry
rescue Dotypos::ServerError
  # 5xx
rescue Dotypos::Error => e
  # catch-all
end
```

Full error hierarchy:

```
Dotypos::Error
├── Dotypos::ConnectionError
├── Dotypos::TimeoutError
└── Dotypos::ClientError
    ├── Dotypos::AuthenticationError   (401)
    ├── Dotypos::ForbiddenError        (403)
    ├── Dotypos::NotFoundError         (404)
    ├── Dotypos::ConflictError         (409)
    ├── Dotypos::PreconditionError     (412)
    ├── Dotypos::UnprocessableError    (422)
    └── Dotypos::RateLimitError        (429)
└── Dotypos::ServerError               (5xx)
```

## Configuration

```ruby
client = Dotypos::Client.new(
  refresh_token: "...",
  cloud_id:      "...",
  timeout:       60,    # read timeout in seconds (default: 30)
  open_timeout:  10,    # connection timeout in seconds (default: 5)
  logger:        Logger.new($stdout)
)
```

## Development

```sh
bundle install
bundle exec rspec
```

## License

MIT — see [LICENSE.md](LICENSE.md).
