require "spec_helper"

RSpec.describe Dotypos::TokenManager do
  subject(:manager) do
    described_class.new(
      refresh_token: REFRESH_TOKEN,
      cloud_id: CLOUD_ID,
      base_url: "https://api.dotykacka.cz/v2/"
    )
  end

  def stub_token(body: AUTH_TOKEN_BODY, status: 200)
    stub_request(:post, AUTH_URL)
      .with(
        headers: { "Authorization" => "User #{REFRESH_TOKEN}" },
        body: hash_including("_cloudId" => CLOUD_ID)
      )
      .to_return(status: status, body: body, headers: { "Content-Type" => "application/json" })
  end

  describe "#access_token" do
    it "fetches a token on first call" do
      stub_token
      expect(manager.access_token).to eq(ACCESS_TOKEN)
    end

    it "returns the cached token on subsequent calls without re-fetching" do
      stub = stub_token
      manager.access_token
      manager.access_token
      expect(stub).to have_been_requested.once
    end

    it "raises AuthenticationError on non-200 response" do
      stub_token(body: '{"error":"invalid"}', status: 401)
      expect { manager.access_token }.to raise_error(Dotypos::AuthenticationError)
    end

    it "raises AuthenticationError when response contains no accessToken" do
      stub_token(body: '{"foo":"bar"}')
      expect { manager.access_token }.to raise_error(Dotypos::AuthenticationError, /No accessToken/)
    end

    it "refreshes when token is expired" do
      stub = stub_token
      manager.access_token # prime the token

      # Simulate expiry by backdating @expires_at
      manager.instance_variable_set(:@expires_at, Time.now - 1)

      manager.access_token
      expect(stub).to have_been_requested.twice
    end
  end

  describe "#force_refresh!" do
    it "fetches a new token even if the current one has not expired" do
      stub = stub_token
      manager.access_token # prime
      manager.force_refresh!
      expect(stub).to have_been_requested.twice
    end

    it "returns the new access token" do
      stub_token
      expect(manager.force_refresh!).to eq(ACCESS_TOKEN)
    end
  end
end
