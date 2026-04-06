require "spec_helper"

RSpec.describe Dotypos::FilterBuilder do
  describe ".build" do
    it "yields a builder and returns the filter string" do
      result = described_class.build do |f|
        f.where(:price, :gteq, 500)
      end
      expect(result).to eq("price|gteq|500")
    end

    it "builds multiple conditions separated by semicolons" do
      result = described_class.build do |f|
        f.where(:price, :gteq, 500)
        f.where(:deleted, :eq, false)
        f.where(:name, :like, "John")
      end
      expect(result).to eq("price|gteq|500;deleted|eq|0;name|like|John")
    end
  end

  describe "#where (chaining)" do
    it "is chainable and returns self" do
      builder = described_class.new
      result  = builder.where(:price, :gteq, 100).where(:deleted, :eq, false)
      expect(result).to be(builder)
      expect(result.to_s).to eq("price|gteq|100;deleted|eq|0")
    end
  end

  describe "value serialization" do
    subject(:builder) { described_class.new }

    it "serializes true as '1'" do
      builder.where(:active, :eq, true)
      expect(builder.to_s).to eq("active|eq|1")
    end

    it "serializes false as '0'" do
      builder.where(:deleted, :eq, false)
      expect(builder.to_s).to eq("deleted|eq|0")
    end

    it "serializes nil as 'null'" do
      builder.where(:external_id, :eq, nil)
      expect(builder.to_s).to eq("externalId|eq|null")
    end

    it "serializes arrays as comma-separated values (for :in)" do
      builder.where(:status, :in, ["open", "closed"])
      expect(builder.to_s).to eq("status|in|open,closed")
    end

    it "serializes numbers as strings" do
      builder.where(:price, :gt, 9.99)
      expect(builder.to_s).to eq("price|gt|9.99")
    end
  end

  describe "key transformation" do
    it "converts snake_case attribute names to camelCase" do
      filter = described_class.build { |f| f.where(:version_date, :gteq, "2024-01-01") }
      expect(filter).to start_with("versionDate|")
    end

    it "converts multi-word snake_case attributes" do
      filter = described_class.build { |f| f.where(:total_items_count, :gt, 0) }
      expect(filter).to start_with("totalItemsCount|")
    end
  end

  describe "operator validation" do
    it "accepts all valid operators" do
      %w[eq ne gt gteq lt lteq like in notin bin bex].each do |op|
        expect {
          described_class.build { |f| f.where(:name, op.to_sym, "value") }
        }.not_to raise_error
      end
    end

    it "raises ArgumentError for invalid operators" do
      expect {
        described_class.build { |f| f.where(:name, :invalid_op, "value") }
      }.to raise_error(ArgumentError, /Invalid filter operator/)
    end
  end

  describe "#to_s" do
    it "returns nil when no conditions are set" do
      expect(described_class.new.to_s).to be_nil
    end
  end

  describe "#empty?" do
    it "returns true when no conditions are added" do
      expect(described_class.new.empty?).to be true
    end

    it "returns false after adding a condition" do
      builder = described_class.new
      builder.where(:name, :eq, "test")
      expect(builder.empty?).to be false
    end
  end
end
