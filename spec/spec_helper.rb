require "webmock/rspec"
require "dotypos"

# Top-level constants — accessible from all spec files
AUTH_TOKEN_BODY = '{"accessToken":"test_access_token"}'.freeze
ACCESS_TOKEN    = "test_access_token".freeze
REFRESH_TOKEN   = "test_refresh_token".freeze
CLOUD_ID        = "111222333".freeze
AUTH_URL        = "https://api.dotykacka.cz/v2/signin/token".freeze
API_BASE        = "https://api.dotykacka.cz/v2/clouds/#{CLOUD_ID}".freeze

module SpecHelpers
  def stub_auth
    stub_request(:post, AUTH_URL)
      .with(
        headers: { "Authorization" => "User #{REFRESH_TOKEN}" },
        body:    hash_including("_cloudId" => CLOUD_ID)
      )
      .to_return(status: 200, body: AUTH_TOKEN_BODY, headers: { "Content-Type" => "application/json" })
  end

  def build_client
    stub_auth
    Dotypos::Client.new(refresh_token: REFRESH_TOKEN, cloud_id: CLOUD_ID)
  end

  def json(hash)
    JSON.generate(hash)
  end

  def api_headers
    { "Content-Type" => "application/json" }
  end
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.disable_monkey_patching!
  config.order = :random
  config.warnings = true

  config.include SpecHelpers

  config.after { Dotypos.reset! }
end
