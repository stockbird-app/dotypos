require_relative "lib/dotypos/version"

Gem::Specification.new do |s|
  s.name        = "dotypos"
  s.version     = Dotypos::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Stockbird Team"]
  s.email       = ["info@stockbird.app"]
  s.homepage    = "https://github.com/stockbird-app/dotypos"
  s.summary     = "Ruby API client for Dotypos (Dotykačka)"
  s.description = "A Ruby gem for interacting with the Dotypos API v2. Handles authentication, " \
                  "token refresh, pagination, and provides a clean interface to all API resources."
  s.license     = "MIT"

  s.metadata = {
    "bug_tracker_uri"   => "https://github.com/stockbird-app/dotypos/issues",
    "source_code_uri"   => "https://github.com/stockbird-app/dotypos",
    "changelog_uri"     => "https://github.com/stockbird-app/dotypos/blob/main/CHANGELOG.md"
  }

  s.required_ruby_version = ">= 3.3.0"

  s.files = Dir["lib/**/*.rb", "LICENSE.md", "README.md"]

  s.add_runtime_dependency "faraday",       "~> 2.7"
  s.add_runtime_dependency "faraday-retry", "~> 2.2"

  s.add_development_dependency "rspec",   "~> 3.13"
  s.add_development_dependency "webmock", "~> 3.23"
  s.add_development_dependency "rake",    "~> 13.0"
end
