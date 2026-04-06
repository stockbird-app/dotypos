require "spec_helper"

RSpec.describe Dotypos::KeyTransformer do
  describe ".snake_key" do
    it "converts lowerCamelCase to snake_case symbol" do
      expect(described_class.snake_key("currentPage")).to eq(:current_page)
    end

    it "strips leading underscore then converts" do
      expect(described_class.snake_key("_cloudId")).to eq(:cloud_id)
    end

    it "handles consecutive uppercase (acronyms)" do
      expect(described_class.snake_key("totalItemsCount")).to eq(:total_items_count)
    end

    it "leaves already-lowercase keys unchanged" do
      expect(described_class.snake_key("name")).to eq(:name)
    end

    it "handles symbol input" do
      expect(described_class.snake_key(:versionDate)).to eq(:version_date)
    end
  end

  describe ".camel_key" do
    it "converts snake_case symbol to lowerCamelCase string" do
      expect(described_class.camel_key(:current_page)).to eq("currentPage")
    end

    it "handles single-word keys" do
      expect(described_class.camel_key(:name)).to eq("name")
    end

    it "handles string input" do
      expect(described_class.camel_key("version_date")).to eq("versionDate")
    end

    it "handles multiple words" do
      expect(described_class.camel_key(:total_items_count)).to eq("totalItemsCount")
    end
  end

  describe ".to_snake" do
    it "recursively transforms hash keys" do
      input = { "currentPage" => 1, "_cloudId" => "123", "perPage" => 20 }
      expect(described_class.to_snake(input)).to eq(
        current_page: 1, cloud_id: "123", per_page: 20
      )
    end

    it "recursively transforms nested hashes" do
      input = { "orderItem" => { "_cloudId" => "5", "totalPrice" => "100" } }
      expect(described_class.to_snake(input)).to eq(
        order_item: { cloud_id: "5", total_price: "100" }
      )
    end

    it "transforms arrays of hashes" do
      input = [{ "firstName" => "Alice" }, { "firstName" => "Bob" }]
      expect(described_class.to_snake(input)).to eq(
        [{ first_name: "Alice" }, { first_name: "Bob" }]
      )
    end

    it "passes through non-hash/array values" do
      expect(described_class.to_snake("hello")).to eq("hello")
      expect(described_class.to_snake(42)).to eq(42)
    end
  end

  describe ".to_camel" do
    it "recursively transforms hash keys to lowerCamelCase strings" do
      input = { current_page: 1, cloud_id: "123" }
      expect(described_class.to_camel(input)).to eq(
        "currentPage" => 1, "cloudId" => "123"
      )
    end

    it "handles nested hashes" do
      input = { order_item: { total_price: "100" } }
      expect(described_class.to_camel(input)).to eq(
        "orderItem" => { "totalPrice" => "100" }
      )
    end
  end
end
