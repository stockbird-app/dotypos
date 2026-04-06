require "spec_helper"

RSpec.describe Dotypos::PagedResult do
  subject(:result) { described_class.new(collection, envelope) }

  let(:client)     { build_client }
  let(:collection) { client.orders }

  def envelope(overrides = {})
    {
      current_page: 1,
      per_page: 20,
      total_items_on_page: 20,
      total_items_count: 60,
      first_page: 1,
      last_page: 3,
      next_page: 2,
      prev_page: nil,
      data: [
        { "id" => "1", "note" => "Table 1" },
        { "id" => "2", "note" => "Table 2" },
      ],
    }.merge(overrides)
  end

  describe "#data" do
    it "returns an array of Resource objects" do
      expect(result.data).to all(be_a(Dotypos::Resource))
    end

    it "has the correct count" do
      expect(result.data.size).to eq(2)
    end

    it "transforms keys on contained resources" do
      expect(result.data.first[:id]).to eq("1")
    end
  end

  describe "#next_page?" do
    it "returns true when next_page number is present" do
      expect(result.next_page?).to be true
    end

    it "returns false when next_page is nil and page is not full" do
      r = described_class.new(collection, envelope(next_page: nil, total_items_on_page: 15, per_page: 20))
      expect(r.next_page?).to be false
    end

    it "infers next page when total_items_on_page equals per_page and next_page is nil" do
      r = described_class.new(collection, envelope(next_page: nil, total_items_on_page: 20, per_page: 20))
      expect(r.next_page?).to be true
    end
  end

  describe "#prev_page?" do
    it "returns false on the first page" do
      expect(result.prev_page?).to be false
    end

    it "returns true when prev_page number is present" do
      r = described_class.new(collection, envelope(current_page: 2, prev_page: 1, next_page: 3))
      expect(r.prev_page?).to be true
    end

    it "infers prev page from current_page > 1 when prev_page is nil" do
      r = described_class.new(collection, envelope(current_page: 3, prev_page: nil))
      expect(r.prev_page?).to be true
    end
  end

  describe "#next_page" do
    it "returns nil when on the last page" do
      r = described_class.new(collection, envelope(next_page: nil, total_items_on_page: 10, per_page: 20))
      expect(r.next_page).to be_nil
    end

    it "fetches the next page" do
      stub_request(:get, "#{API_BASE}/order")
        .with(query: { "page" => "2" })
        .to_return(
          status: 200,
          body: json({ currentPage: 2, perPage: 20, totalItemsOnPage: 5,
                       totalItemsCount: 25, firstPage: 1, lastPage: 3,
                       nextPage: nil, prevPage: 1, data: [] }),
          headers: api_headers
        )

      next_result = result.next_page
      expect(next_result).to be_a(described_class)
      expect(next_result.current_page).to eq(2)
    end
  end

  describe "#prev_page" do
    it "returns nil when on the first page" do
      expect(result.prev_page).to be_nil
    end

    it "fetches the previous page" do
      r = described_class.new(collection, envelope(current_page: 2, prev_page: 1))

      stub_request(:get, "#{API_BASE}/order")
        .with(query: { "page" => "1" })
        .to_return(
          status: 200,
          body: json({ currentPage: 1, perPage: 20, totalItemsOnPage: 20,
                       totalItemsCount: 40, firstPage: 1, lastPage: 2,
                       nextPage: 2, prevPage: nil, data: [] }),
          headers: api_headers
        )

      prev_result = r.prev_page
      expect(prev_result).to be_a(described_class)
      expect(prev_result.current_page).to eq(1)
    end
  end

  describe "metadata accessors" do
    it "exposes current_page" do
      expect(result.current_page).to eq(1)
    end

    it "exposes per_page" do
      expect(result.per_page).to eq(20)
    end

    it "exposes total_items_count" do
      expect(result.total_items_count).to eq(60)
    end

    it "exposes first_page" do
      expect(result.first_page).to eq(1)
    end

    it "exposes last_page" do
      expect(result.last_page).to eq(3)
    end
  end
end
