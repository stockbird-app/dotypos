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
      stub_request(:get, "#{API_BASE}/orders")
        .to_return(status: 200, body: json(list_response), headers: api_headers)

      result = collection.list
      expect(result).to be_a(Dotypos::PagedResult)
    end

    it "populates data with Resource objects" do
      stub_request(:get, "#{API_BASE}/orders")
        .to_return(status: 200, body: json(list_response), headers: api_headers)

      resources = collection.list.data
      expect(resources).to all(be_a(Dotypos::Resource))
      expect(resources.first.note).to eq("Table 4")
    end

    it "passes page and limit params" do
      stub = stub_request(:get, "#{API_BASE}/orders")
             .with(query: { "page" => "2", "limit" => "50" })
             .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(page: 2, limit: 50)
      expect(stub).to have_been_requested.once
    end

    it "passes a raw filter string" do
      stub = stub_request(:get, "#{API_BASE}/orders")
             .with(query: { "filter" => "deleted|eq|0" })
             .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(filter: "deleted|eq|0")
      expect(stub).to have_been_requested.once
    end

    it "accepts a FilterBuilder object for the filter param" do
      filter = Dotypos::FilterBuilder.build { |f| f.where(:deleted, :eq, false) }
      stub = stub_request(:get, "#{API_BASE}/orders")
             .with(query: { "filter" => "deleted|eq|0" })
             .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(filter: filter)
      expect(stub).to have_been_requested.once
    end

    it "omits nil params" do
      stub = stub_request(:get, "#{API_BASE}/orders")
             .with(query: {})
             .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list(filter: nil)
      expect(stub).to have_been_requested.once
    end

    context "with include: parameter" do
      it "translates a snake_case symbol to camelCase include query param" do
        stub = stub_request(:get, "#{API_BASE}/orders")
               .with(query: hash_including("include" => "orderItems"))
               .to_return(status: 200, body: json(list_response), headers: api_headers)

        collection.list(include: :order_items)
        expect(stub).to have_been_requested.once
      end

      it "translates an array of snake_case symbols to a comma-separated camelCase string" do
        stub = stub_request(:get, "#{API_BASE}/orders")
               .with(query: hash_including("include" => "orderItems,moneyLogs"))
               .to_return(status: 200, body: json(list_response), headers: api_headers)

        collection.list(include: %i[order_items money_logs])
        expect(stub).to have_been_requested.once
      end

      it "passes a raw camelCase string through unchanged" do
        stub = stub_request(:get, "#{API_BASE}/orders")
               .with(query: hash_including("include" => "orderItems"))
               .to_return(status: 200, body: json(list_response), headers: api_headers)

        collection.list(include: "orderItems")
        expect(stub).to have_been_requested.once
      end

      it "omits the include param when nil" do
        stub = stub_request(:get, "#{API_BASE}/orders")
               .with(query: {})
               .to_return(status: 200, body: json(list_response), headers: api_headers)

        collection.list(include: nil)
        expect(stub).to have_been_requested.once
      end

      it "exposes nested orderItems as Resource instances with dot access" do
        item_payload = { "id" => "99", "quantity" => 2, "totalPrice" => "19.80" }
        response_with_items = list_response.merge(
          data: [order_payload.merge("orderItems" => [item_payload])]
        )
        stub_request(:get, "#{API_BASE}/orders")
          .with(query: hash_including("include" => "orderItems"))
          .to_return(status: 200, body: json(response_with_items), headers: api_headers)

        order = collection.list(include: :order_items).data.first
        expect(order.order_items).to be_an(Array)
        expect(order.order_items.first).to be_a(Dotypos::Resource)
        expect(order.order_items.first.quantity).to eq(2)
      end

      it "carries the include param through to next_page requests" do
        page1_response = list_response.merge(
          currentPage: 1, perPage: 1, totalItemsOnPage: 1, totalItemsCount: 2,
          nextPage: 2
        )
        page2_response = list_response.merge(
          currentPage: 2, perPage: 1, totalItemsOnPage: 1, totalItemsCount: 2,
          nextPage: nil
        )

        stub_request(:get, "#{API_BASE}/orders")
          .with(query: hash_including("include" => "orderItems", "page" => "1"))
          .to_return(status: 200, body: json(page1_response), headers: api_headers)

        next_stub = stub_request(:get, "#{API_BASE}/orders")
                    .with(query: hash_including("include" => "orderItems", "page" => "2"))
                    .to_return(status: 200, body: json(page2_response), headers: api_headers)

        result = collection.list(page: 1, include: :order_items)
        result.next_page
        expect(next_stub).to have_been_requested.once
      end
    end

    it "sends Allow-Version: BC1 header so empty collections return 200 instead of 404" do
      stub = stub_request(:get, "#{API_BASE}/orders")
             .with(headers: { "Allow-Version" => "BC1" })
             .to_return(status: 200, body: json(list_response), headers: api_headers)

      collection.list
      expect(stub).to have_been_requested.once
    end

    it "returns an empty PagedResult when the collection has no items (BC1 200 response)" do
      empty_response = {
        currentPage: 1, perPage: 20, totalItemsOnPage: 0,
        totalItemsCount: 0, firstPage: 1, lastPage: 1,
        nextPage: nil, prevPage: nil,
        data: []
      }
      stub_request(:get, "#{API_BASE}/orders")
        .to_return(status: 200, body: json(empty_response), headers: api_headers)

      result = collection.list
      expect(result).to be_a(Dotypos::PagedResult)
      expect(result.data).to be_empty
      expect(result.total_items_count).to eq(0)
    end
  end

  describe "#get" do
    it "returns a Resource with the ETag set" do
      stub_request(:get, "#{API_BASE}/orders/100")
        .to_return(
          status: 200,
          body: json(order_payload),
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
      stub = stub_request(:post, "#{API_BASE}/orders")
             .with(body: hash_including("note" => "Table 5"))
             .to_return(
               status: 201,
               body: json(order_payload.merge("note" => "Table 5")),
               headers: api_headers
             )

      resource = collection.create(note: "Table 5")
      expect(resource).to be_a(Dotypos::Resource)
      expect(resource.note).to eq("Table 5")
      expect(stub).to have_been_requested.once
    end

    it "converts snake_case keys to camelCase in the request body" do
      stub = stub_request(:post, "#{API_BASE}/orders")
             .with(body: hash_including("totalPrice" => "99.99"))
             .to_return(status: 201, body: json(order_payload), headers: api_headers)

      collection.create(total_price: "99.99")
      expect(stub).to have_been_requested.once
    end

    it "returns an array of Resources for batch responses" do
      stub_request(:post, "#{API_BASE}/orders")
        .to_return(status: 201, body: json([order_payload, order_payload]), headers: api_headers)

      result = collection.create([{ note: "A" }, { note: "B" }])
      expect(result).to be_an(Array)
      expect(result).to all(be_a(Dotypos::Resource))
    end
  end

  describe "#update" do
    let(:resource) { Dotypos::Resource.new(order_payload, etag: '"original_etag"') }

    it "sends PATCH with If-Match header when given a Resource" do
      stub = stub_request(:patch, "#{API_BASE}/orders/100")
             .with(headers: { "If-Match" => '"original_etag"' })
             .to_return(status: 200, body: json(order_payload), headers: api_headers)

      collection.update(resource, note: "Updated")
      expect(stub).to have_been_requested.once
    end

    it "sends PATCH with explicit etag keyword arg" do
      stub = stub_request(:patch, "#{API_BASE}/orders/100")
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
      stub_request(:patch, "#{API_BASE}/orders/100")
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
      stub = stub_request(:put, "#{API_BASE}/orders/100")
             .with(headers: { "If-Match" => '"original_etag"' })
             .to_return(status: 200, body: json(order_payload), headers: api_headers)

      collection.replace(resource, order_payload)
      expect(stub).to have_been_requested.once
    end
  end

  describe "#delete" do
    it "sends DELETE and returns true" do
      stub_request(:delete, "#{API_BASE}/orders/100")
        .to_return(status: 204, body: "", headers: {})

      expect(collection.delete("100")).to be true
    end
  end
end
