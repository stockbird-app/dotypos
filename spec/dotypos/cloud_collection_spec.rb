require "spec_helper"

RSpec.describe Dotypos::CloudCollection do
  let(:client)     { build_client }
  let(:collection) { client.clouds }

  let(:clouds_index_url) { "https://api.dotykacka.cz/v2/clouds" }
  let(:cloud_member_url) { "https://api.dotykacka.cz/v2/clouds/#{CLOUD_ID}" }

  let(:cloud_payload) do
    { "id" => CLOUD_ID, "_cloudId" => CLOUD_ID, "name" => "Test Cloud",
      "versionDate" => "1700000000000" }
  end

  describe "#list" do
    let(:list_response) do
      {
        currentPage: 1, perPage: 20, totalItemsOnPage: 1,
        totalItemsCount: 1, firstPage: 1, lastPage: 1,
        nextPage: nil, prevPage: nil,
        data: [cloud_payload]
      }
    end

    it "GETs /v2/clouds (not under clouds/:cloudId)" do
      stub = stub_request(:get, clouds_index_url)
             .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list
      expect(stub).to have_been_requested.once
    end

    it "returns a PagedResult with Resource data" do
      stub_request(:get, clouds_index_url)
        .to_return(status: 200, body: json(list_response), headers: api_headers)

      result = collection.list
      expect(result).to be_a(Dotypos::PagedResult)
      expect(result.data).to all(be_a(Dotypos::Resource))
      expect(result.data.first.name).to eq("Test Cloud")
    end

    it "passes list query params" do
      stub = stub_request(:get, clouds_index_url)
             .with(query: { "page" => "2", "limit" => "10" })
             .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(page: 2, limit: 10)
      expect(stub).to have_been_requested.once
    end
  end

  describe "#get" do
    it "GETs /v2/clouds/:id" do
      stub = stub_request(:get, cloud_member_url)
             .to_return(
               status: 200,
               body: json(cloud_payload),
               headers: api_headers.merge("ETag" => '"cloud_etag"')
             )

      resource = collection.get(CLOUD_ID)
      expect(stub).to have_been_requested.once
      expect(resource).to be_a(Dotypos::Resource)
      expect(resource.id).to eq(CLOUD_ID)
      expect(resource.etag).to eq('"cloud_etag"')
    end
  end
end
