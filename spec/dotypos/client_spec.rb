require "spec_helper"

RSpec.describe Dotypos::Client do
  subject(:client) { build_client }

  describe "initialization" do
    it "stores the cloud_id" do
      expect(client.cloud_id).to eq(CLOUD_ID)
    end

    it "accepts optional timeout arguments" do
      stub_auth
      c = described_class.new(
        refresh_token: REFRESH_TOKEN, cloud_id: CLOUD_ID,
        timeout: 60, open_timeout: 10
      )
      expect(c.cloud_id).to eq(CLOUD_ID)
    end
  end

  describe "resource accessors" do
    Dotypos::Client::RESOURCES.each do |method_name, path|
      it "responds to ##{method_name} and returns a ResourceCollection for '#{path}'" do
        collection = client.public_send(method_name)
        expect(collection).to be_a(Dotypos::ResourceCollection)
      end
    end

    it "supports arbitrary paths via #resource" do
      expect(client.resource("custom-path")).to be_a(Dotypos::ResourceCollection)
    end
  end

  describe "#request" do
    let(:endpoint) { "#{API_BASE}/product" }

    it "sends Bearer token in Authorization header" do
      stub = stub_request(:get, endpoint)
               .with(headers: { "Authorization" => "Bearer #{ACCESS_TOKEN}" })
               .to_return(status: 200, body: json({ id: "1" }), headers: api_headers)

      client.request(:get, "clouds/#{CLOUD_ID}/product")
      expect(stub).to have_been_requested.once
    end

    it "sends User-Agent header" do
      stub = stub_request(:get, endpoint)
               .with(headers: { "User-Agent" => /dotypos-ruby\// })
               .to_return(status: 200, body: json({ id: "1" }), headers: api_headers)

      client.request(:get, "clouds/#{CLOUD_ID}/product")
      expect(stub).to have_been_requested.once
    end

    it "retries once on 401 by force-refreshing the token" do
      # First call returns 401, second returns 200
      stub_request(:get, endpoint)
        .to_return(
          { status: 401, body: '{"error":"ACCESS_TOKEN_EXPIRED"}', headers: api_headers },
          { status: 200, body: json({ id: "1" }), headers: api_headers }
        )

      # The token manager will be asked to force_refresh after the 401
      stub_request(:post, AUTH_URL)
        .to_return(status: 200, body: AUTH_TOKEN_BODY, headers: api_headers)

      result = client.request(:get, "clouds/#{CLOUD_ID}/product")
      expect(result[:body]).to eq({ "id" => "1" })
    end

    it "raises AuthenticationError on persistent 401" do
      stub_request(:get, endpoint)
        .to_return(status: 401, body: '{"error":"INVALID_REFRESH_TOKEN"}', headers: api_headers)
      stub_request(:post, AUTH_URL)
        .to_return(status: 200, body: AUTH_TOKEN_BODY, headers: api_headers)

      expect { client.request(:get, "clouds/#{CLOUD_ID}/product") }
        .to raise_error(Dotypos::AuthenticationError)
    end

    it "raises NotFoundError on 404" do
      stub_request(:get, endpoint)
        .to_return(status: 404, body: json({ message: "Not found" }), headers: api_headers)

      expect { client.request(:get, "clouds/#{CLOUD_ID}/product") }
        .to raise_error(Dotypos::NotFoundError)
    end

    it "raises RateLimitError on 429" do
      stub_request(:get, endpoint)
        .to_return(status: 429, body: "", headers: api_headers)

      expect { client.request(:get, "clouds/#{CLOUD_ID}/product") }
        .to raise_error(Dotypos::RateLimitError)
    end

    it "raises PreconditionError on 412" do
      stub_request(:patch, endpoint)
        .to_return(status: 412, body: json({ message: "ETag mismatch" }), headers: api_headers)

      expect { client.request(:patch, "clouds/#{CLOUD_ID}/product", headers: { "If-Match" => "old" }) }
        .to raise_error(Dotypos::PreconditionError)
    end

    it "raises ServerError on 500" do
      stub_request(:get, endpoint)
        .to_return(status: 500, body: json({ message: "Internal error" }), headers: api_headers)

      expect { client.request(:get, "clouds/#{CLOUD_ID}/product") }
        .to raise_error(Dotypos::ServerError)
    end

    it "raises ConnectionError on network failure" do
      stub_request(:get, endpoint).to_raise(Faraday::ConnectionFailed.new("Connection refused"))

      expect { client.request(:get, "clouds/#{CLOUD_ID}/product") }
        .to raise_error(Dotypos::ConnectionError)
    end

    it "includes the ETag from response headers in the result" do
      stub_request(:get, endpoint)
        .to_return(
          status:  200,
          body:    json({ id: "1" }),
          headers: api_headers.merge("ETag" => '"etag_abc"')
        )

      result = client.request(:get, "clouds/#{CLOUD_ID}/product")
      expect(result[:etag]).to eq('"etag_abc"')
    end
  end
end
