require "spec_helper"

RSpec.describe Dotypos::ResourceCollection do
  let(:client)     { build_client }
  let(:collection) { client.orders }

  let(:order_payload) do
    { "id" => "100", "_cloudId" => CLOUD_ID, "note" => "Table 4",
      "totalPrice" => "49.90", "versionDate" => "1700000000000" }
  end

  describe "#list" do
    let(:list_response) do
      {
        currentPage: 1, perPage: 20, totalItemsOnPage: 1,
        totalItemsCount: 1, firstPage: 1, lastPage: 1,
        nextPage: nil, prevPage: nil,
        data: [order_payload]
      }
    end

    it "returns a PagedResult" do
      stub_request(:get, "#{API_BASE}/order")
        .to_return(status: 200, body: json(list_response), headers: api_headers)

      result = collection.list
      expect(result).to be_a(Dotypos::PagedResult)
    end

    it "populates data with Resource objects" do
      stub_request(:get, "#{API_BASE}/order")
        .to_return(status: 200, body: json(list_response), headers: api_headers)

      resources = collection.list.data
      expect(resources).to all(be_a(Dotypos::Resource))
      expect(resources.first.note).to eq("Table 4")
    end

    it "passes page and limit params" do
      stub = stub_request(:get, "#{API_BASE}/order")
               .with(query: { "page" => "2", "limit" => "50" })
               .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(page: 2, limit: 50)
      expect(stub).to have_been_requested.once
    end

    it "passes a raw filter string" do
      stub = stub_request(:get, "#{API_BASE}/order")
               .with(query: { "filter" => "deleted|eq|0" })
               .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(filter: "deleted|eq|0")
      expect(stub).to have_been_requested.once
    end

    it "accepts a FilterBuilder object for the filter param" do
      filter = Dotypos::FilterBuilder.build { |f| f.where(:deleted, :eq, false) }
      stub = stub_request(:get, "#{API_BASE}/order")
               .with(query: { "filter" => "deleted|eq|0" })
               .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(filter: filter)
      expect(stub).to have_been_requested.once
    end

    it "omits nil params" do
      stub = stub_request(:get, "#{API_BASE}/order")
               .with(query: {})
               .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(filter: nil)
      expect(stub).to have_been_requested.once
    end
  end

  describe "#get" do
    it "returns a Resource with the ETag set" do
      stub_request(:get, "#{API_BASE}/order/100")
        .to_return(
          status:  200,
          body:    json(order_payload),
          headers: api_headers.merge("ETag" => '"etag_value"')
        )

      resource = collection.get("100")
      expect(resource).to be_a(Dotypos::Resource)
      expect(resource.note).to eq("Table 4")
      expect(resource.etag).to eq('"etag_value"')
    end
  end

  describe "#create" do
    it "POSTs camelCase body and returns a Resource" do
      stub = stub_request(:post, "#{API_BASE}/order")
               .with(body: hash_including("note" => "Table 5"))
               .to_return(
                 status:  201,
                 body:    json(order_payload.merge("note" => "Table 5")),
                 headers: api_headers
               )

      resource = collection.create(note: "Table 5")
      expect(resource).to be_a(Dotypos::Resource)
      expect(resource.note).to eq("Table 5")
      expect(stub).to have_been_requested.once
    end

    it "converts snake_case keys to camelCase in the request body" do
      stub = stub_request(:post, "#{API_BASE}/order")
               .with(body: hash_including("totalPrice" => "99.99"))
               .to_return(status: 201, body: json(order_payload), headers: api_headers)

      collection.create(total_price: "99.99")
      expect(stub).to have_been_requested.once
    end

    it "returns an array of Resources for batch responses" do
      stub_request(:post, "#{API_BASE}/order")
        .to_return(status: 201, body: json([order_payload, order_payload]), headers: api_headers)

      result = collection.create([{ note: "A" }, { note: "B" }])
      expect(result).to be_an(Array)
      expect(result).to all(be_a(Dotypos::Resource))
    end
  end

  describe "#update" do
    let(:resource) { Dotypos::Resource.new(order_payload, etag: '"original_etag"') }

    it "sends PATCH with If-Match header when given a Resource" do
      stub = stub_request(:patch, "#{API_BASE}/order/100")
               .with(headers: { "If-Match" => '"original_etag"' })
               .to_return(status: 200, body: json(order_payload), headers: api_headers)

      collection.update(resource, note: "Updated")
      expect(stub).to have_been_requested.once
    end

    it "sends PATCH with explicit etag keyword arg" do
      stub = stub_request(:patch, "#{API_BASE}/order/100")
               .with(headers: { "If-Match" => '"explicit_etag"' })
               .to_return(status: 200, body: json(order_payload), headers: api_headers)

      collection.update("100", { note: "Updated" }, etag: '"explicit_etag"')
      expect(stub).to have_been_requested.once
    end

    it "raises ArgumentError when no etag is available" do
      resource_without_etag = Dotypos::Resource.new(order_payload)
      expect { collection.update(resource_without_etag) }
        .to raise_error(ArgumentError, /ETag is required/)
    end

    it "returns the updated Resource" do
      stub_request(:patch, "#{API_BASE}/order/100")
        .to_return(status: 200, body: json(order_payload.merge("note" => "Updated")),
                   headers: api_headers)

      updated = collection.update(resource, note: "Updated")
      expect(updated).to be_a(Dotypos::Resource)
      expect(updated.note).to eq("Updated")
    end
  end

  describe "#replace" do
    let(:resource) { Dotypos::Resource.new(order_payload, etag: '"original_etag"') }

    it "sends PUT with If-Match header" do
      stub = stub_request(:put, "#{API_BASE}/order/100")
               .with(headers: { "If-Match" => '"original_etag"' })
               .to_return(status: 200, body: json(order_payload), headers: api_headers)

      collection.replace(resource, order_payload)
      expect(stub).to have_been_requested.once
    end
  end

  describe "#delete" do
    it "sends DELETE and returns true" do
      stub_request(:delete, "#{API_BASE}/order/100")
        .to_return(status: 204, body: "", headers: {})

      expect(collection.delete("100")).to be true
    end
  end
end
