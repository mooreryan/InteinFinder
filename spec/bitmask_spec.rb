require_relative "lib_helper"

RSpec.describe InteinFinder::Bitmask do
  it { is_expected.to respond_to :mask }

  let(:bitmask) do
    InteinFinder::Bitmask.new :apple, :pie
  end

  describe "#new" do
    it "sets the fields with the keys" do
      expected = { apple: 0b01, pie: 0b10 }

      expect(bitmask.fields).to eq expected
    end
  end

  describe "#set_flag" do
    it "sets the flag to true"
end
