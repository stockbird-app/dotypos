# AGENTS.md

Guidance for AI agents working in this repository.

## Project overview

This is a Ruby gem (`dotypos`) — an API client for the Dotypos (Dotykačka) POS system API v2. It is maintained by the Stockbird team.

**API documentation:** https://docs.api.dotypos.com/ — the authoritative source of truth for all endpoint paths, request/response shapes, authentication flows, and resource definitions.

## Repository layout

```
lib/dotypos/
├── version.rb             # VERSION constant only
├── configuration.rb       # Default timeouts; API_BASE_URL constant
├── errors.rb              # Full error class hierarchy
├── key_transformer.rb     # camelCase ↔ snake_case key conversion
├── token_manager.rb       # Thread-safe OAuth token refresh
├── resource.rb            # Generic response object (dot + hash access)
├── paged_result.rb        # Paginated list wrapper
├── filter_builder.rb      # Filter query string DSL
├── resource_collection.rb # CRUD operations for any resource path
└── client.rb              # Public entry point; all resource accessors

spec/dotypos/              # RSpec tests (one file per lib file)
spec/spec_helper.rb        # WebMock setup; shared helpers and top-level constants
```

## Development commands

```sh
bundle install             # install dependencies
bundle exec rspec          # run full test suite
bundle exec rspec spec/dotypos/client_spec.rb  # run a single spec file
```

Ruby version is pinned in `.ruby-version` (managed via asdf).

## Key conventions

- **No new classes for entity types.** All 16+ API resource types are handled by the single generic `ResourceCollection` + `Resource` pair. Add new resources only as entries in `Client::RESOURCES`.
- **All API keys are snake_case symbols** in Ruby. Conversion happens in `KeyTransformer` — do not apply transformations elsewhere.
- **ETags are stored on `Resource#etag`** and must be passed automatically through `ResourceCollection#update` / `#replace` when a `Resource` object is provided. Never strip ETag handling.
- **Base URL uses a trailing slash** (`https://api.dotykacka.cz/v2/`). All request paths must be relative (no leading `/`) so Faraday preserves the `/v2/` base path. This is a non-obvious Faraday behaviour — do not change it.
- **Token refresh is lazy** — the `TokenManager` fetches the first token on the first API call, not at `Client.new`. This keeps construction side-effect-free.

## Testing

- Tests use **RSpec + WebMock** (no VCR cassettes).
- Shared test constants (`CLOUD_ID`, `AUTH_URL`, etc.) are defined at the **top level** of `spec/spec_helper.rb` — not inside a module — so they are accessible as bare constants in all spec files.
- Every spec that makes HTTP calls must stub auth via `stub_auth` or `build_client` before making requests.
- Run the full suite before committing; all 117 examples must pass.

## Dependency policy

- Runtime dependencies are limited to `faraday` and `faraday-retry`. Do not add further runtime dependencies without discussion.
- Development dependencies: `rspec`, `webmock`, `rake`.
