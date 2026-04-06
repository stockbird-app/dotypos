# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-07

### Added

- `Dotypos::Client` — entry point supporting all 16 Dotypos API resource types
- `Dotypos::TokenManager` — thread-safe OAuth token management; automatically refreshes the access token before expiry and retries transparently on 401
- `Dotypos::ResourceCollection` — generic CRUD interface (`list`, `get`, `create`, `update`, `replace`, `delete`) for any API resource path
- `Dotypos::Resource` — generic response object with dot notation, hash access (`[]`), and `to_h`; stores ETag for safe PUT/PATCH operations
- `Dotypos::PagedResult` — wraps paginated list responses with `next_page?`, `prev_page?`, `next_page`, and `prev_page` for transparent pagination
- `Dotypos::FilterBuilder` — DSL for building Dotypos filter query strings; supports all operators (`eq`, `ne`, `gt`, `gteq`, `lt`, `lteq`, `like`, `in`, `notin`, `bin`, `bex`)
- `Dotypos::KeyTransformer` — bidirectional conversion between API camelCase / `_`-prefixed keys and Ruby snake_case symbols
- Full error hierarchy under `Dotypos::Error` covering 401, 403, 404, 409, 412, 422, 429, 5xx, and network-level errors
- Automatic ETag handling for PUT/PATCH — pass a `Resource` object and the ETag is extracted automatically

[Unreleased]: https://github.com/stockbird-app/dotypos/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/stockbird-app/dotypos/releases/tag/v0.1.0
