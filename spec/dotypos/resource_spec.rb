require "spec_helper"

RSpec.describe Dotypos::Resource do
  subject(:resource) do
    described_class.new(
      { "currentPage" => 1, "_cloudId" => "123", "name" => "Test", "totalPrice" => "9.99" },
      etag: "abc123"
    )
  end

  describe "key transformation" do
    it "converts camelCase keys to snake_case symbols" do
      expect(resource[:current_page]).to eq(1)
    end

    it "strips leading underscore and converts" do
      expect(resource[:cloud_id]).to eq("123")
    end

    it "converts multi-word camelCase keys" do
      expect(resource[:total_price]).to eq("9.99")
    end
  end

  describe "dot notation access" do
    it "provides dot-notation for attributes" do
      expect(resource.name).to eq("Test")
    end

    it "provides dot-notation for transformed keys" do
      expect(resource.total_price).to eq("9.99")
    end

    it "raises NoMethodError for unknown attributes" do
      expect { resource.nonexistent }.to raise_error(NoMethodError)
    end
  end

  describe "#[]" do
    it "accepts symbol keys" do
      expect(resource[:name]).to eq("Test")
    end

    it "accepts string keys and converts them" do
      expect(resource["name"]).to eq("Test")
    end

    it "accepts camelCase string keys" do
      expect(resource["totalPrice"]).to eq("9.99")
    end
  end

  describe "#to_h" do
    it "returns a plain hash with snake_case symbol keys" do
      hash = resource.to_h
      expect(hash).to be_a(Hash)
      expect(hash[:name]).to eq("Test")
      expect(hash[:total_price]).to eq("9.99")
      expect(hash[:cloud_id]).to eq("123")
    end

    it "returns a deep copy (not the internal state)" do
      hash = resource.to_h
      hash[:name] = "Modified"
      expect(resource.name).to eq("Test")
    end
  end

  describe "#etag" do
    it "stores the ETag from initialization" do
      expect(resource.etag).to eq("abc123")
    end

    it "allows updating the ETag" do
      resource.etag = "new_etag"
      expect(resource.etag).to eq("new_etag")
    end
  end

  describe "#respond_to_missing?" do
    it "returns true for known attributes" do
      expect(resource.respond_to?(:name)).to be true
    end

    it "returns false for unknown attributes" do
      expect(resource.respond_to?(:nonexistent)).to be false
    end
  end

  describe "nested collection wrapping" do
    let(:item_payload) { { "id" => "99", "quantity" => 2, "totalPrice" => "19.80" } }

    it "wraps orderItems arrays as Resource instances" do
      order = described_class.new({ "id" => "1", "orderItems" => [item_payload] })
      expect(order.order_items).to be_an(Array)
      expect(order.order_items.first).to be_a(described_class)
    end

    it "provides dot access on nested order item resources" do
      order = described_class.new({ "id" => "1", "orderItems" => [item_payload] })
      expect(order.order_items.first.quantity).to eq(2)
      expect(order.order_items.first.total_price).to eq("19.80")
    end

    it "wraps moneyLogs arrays as Resource instances" do
      log_payload = { "id" => "55", "amount" => "10.00" }
      order = described_class.new({ "id" => "1", "moneyLogs" => [log_payload] })
      expect(order.money_logs.first).to be_a(described_class)
      expect(order.money_logs.first.amount).to eq("10.00")
    end

    it "leaves other nested arrays untouched" do
      order = described_class.new({ "id" => "1", "tags" => %w[foo bar] })
      expect(order.tags).to eq(%w[foo bar])
    end

    it "returns plain hashes for nested items via #to_h (no Resource instances leak)" do
      order = described_class.new({ "id" => "1", "orderItems" => [item_payload] })
      h = order.to_h
      expect(h[:order_items]).to be_an(Array)
      expect(h[:order_items].first).to be_a(Hash)
      expect(h[:order_items].first).not_to be_a(described_class)
      expect(h[:order_items].first[:total_price]).to eq("19.80")
    end
  end

  describe "#==" do
    it "is equal to another Resource with same attributes" do
      other = described_class.new(
        { "currentPage" => 1, "_cloudId" => "123", "name" => "Test", "totalPrice" => "9.99" }
      )
      expect(resource).to eq(other)
    end

    it "is not equal to a Resource with different attributes" do
      other = described_class.new({ "name" => "Different" })
      expect(resource).not_to eq(other)
    end

    it "is equal to another Resource with the same nested orderItems" do
      payload = { "id" => "1", "orderItems" => [{ "id" => "99", "quantity" => 2 }] }
      a = described_class.new(payload)
      b = described_class.new(payload)
      expect(a).to eq(b)
    end
  end
end
