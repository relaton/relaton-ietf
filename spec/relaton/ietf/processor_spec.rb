require "relaton/ietf/processor"
require "relaton/ietf/data_fetcher"

RSpec.describe Relaton::Ietf::Processor do
  subject { described_class.new }

  it "short returns :relaton_ietf" do
    expect(subject.short).to eq :relaton_ietf
  end

  it "prefix returns IETF" do
    expect(subject.prefix).to eq "IETF"
  end

  it "idtype returns IETF" do
    expect(subject.idtype).to eq "IETF"
  end

  it "datasets returns all three dataset names" do
    expect(subject.datasets).to eq %w[ietf-rfcsubseries ietf-internet-drafts ietf-rfc-entries]
  end

  describe "defaultprefix" do
    %w[RFC\ 1234 BCP\ 1 I-D.foo I-D\ foo IETF\ foo FYI\ 1 STD\ 1].each do |ref|
      it "matches #{ref.inspect}" do
        expect(subject.defaultprefix).to match(ref)
      end
    end

    %w[ISO\ 123 W3C\ xml].each do |ref|
      it "does not match #{ref.inspect}" do
        expect(subject.defaultprefix).not_to match(ref)
      end
    end
  end

  describe "#get" do
    it "delegates to Bibliography.get" do
      expect(Relaton::Ietf::Bibliography).to receive(:get)
        .with("RFC 8341", "2018", {}).and_return(:item)
      expect(subject.get("RFC 8341", "2018", {})).to be :item
    end
  end

  describe "#fetch_data" do
    it "delegates to DataFetcher.fetch" do
      allow(subject).to receive(:require_relative)
      expect(Relaton::Ietf::DataFetcher).to receive(:fetch)
        .with("ietf-rfcsubseries", output: "dir", format: "xml").and_return(:result)
      expect(subject.fetch_data("ietf-rfcsubseries", output: "dir", format: "xml")).to be :result
    end
  end

  describe "#from_xml" do
    it "delegates to Item.from_xml" do
      expect(Relaton::Ietf::Item).to receive(:from_xml).with(:xml).and_return(:item)
      expect(subject.from_xml(:xml)).to be :item
    end
  end

  describe "#from_yaml" do
    it "delegates to Item.from_yaml" do
      expect(Relaton::Ietf::Item).to receive(:from_yaml).with(:yaml).and_return(:item)
      expect(subject.from_yaml(:yaml)).to be :item
    end
  end

  describe "#grammar_hash" do
    it "delegates to Relaton::Ietf.grammar_hash" do
      expect(Relaton::Ietf).to receive(:grammar_hash).once.and_return("hash123")
      expect(subject.grammar_hash).to eq "hash123"
    end

    it "memoizes the result" do
      expect(Relaton::Ietf).to receive(:grammar_hash).once.and_return("hash123")
      2.times { expect(subject.grammar_hash).to eq "hash123" }
    end
  end

  describe "#remove_index_file" do
    it "removes index files for RFC, RSS, and IDS" do
      %i[RFC RSS IDS].each do |type|
        idx = double("index_#{type}")
        expect(idx).to receive(:remove_file)
        expect(Relaton::Index).to receive(:find_or_create)
          .with(type, url: true, file: "index-v1.yaml").and_return(idx)
      end
      subject.remove_index_file
    end
  end
end
