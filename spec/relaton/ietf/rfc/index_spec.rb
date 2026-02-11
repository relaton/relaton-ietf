# frozen_string_literal: true

RSpec.describe Relaton::Ietf::Rfc::Index do
  let(:xml) { File.read("spec/fixtures/ietf_rfcsubseries.xml") }
  subject { described_class.from_xml(xml) }

  it "parses bcp-entries" do
    expect(subject.bcp_entries.size).to eq 6
    expect(subject.bcp_entries.first.doc_id).to eq "BCP0001"
    expect(subject.bcp_entries.last.doc_id).to eq "BCP0006"
  end

  it "parses fyi-entries" do
    expect(subject.fyi_entries.size).to eq 2
    expect(subject.fyi_entries.first.doc_id).to eq "FYI0002"
    expect(subject.fyi_entries.last.doc_id).to eq "FYI0003"
  end

  it "parses std-entries" do
    expect(subject.std_entries.size).to eq 3
    expect(subject.std_entries.first.doc_id).to eq "STD0001"
    expect(subject.std_entries.last.doc_id).to eq "STD0003"
  end

  it "parses is-also references within entries" do
    # BCP0006 has multiple is-also references
    bcp6 = subject.bcp_entries.find { |e| e.doc_id == "BCP0006" }
    expect(bcp6.is_also.doc_id).to eq ["RFC1930", "RFC6996", "RFC7300"]
  end

  it "parses entries without is-also" do
    # BCP0001 and BCP0002 have no is-also
    bcp1 = subject.bcp_entries.find { |e| e.doc_id == "BCP0001" }
    expect(bcp1.is_also).to be_nil
  end

  it "parses title in std-entry" do
    std1 = subject.std_entries.find { |e| e.doc_id == "STD0001" }
    expect(std1.title).to include("[STD number 1 is retired")

    std3 = subject.std_entries.find { |e| e.doc_id == "STD0003" }
    expect(std3.title).to eq "Requirements for Internet Hosts"
  end

  describe "#subseries_entries" do
    it "returns all entries combined" do
      # 6 bcp + 2 fyi + 3 std = 11
      expect(subject.subseries_entries.size).to eq 11
    end

    it "returns entries in correct order" do
      entries = subject.subseries_entries
      expect(entries.first.doc_id).to eq "BCP0001"
      expect(entries[6].doc_id).to eq "FYI0002"
      expect(entries[8].doc_id).to eq "STD0001"
    end
  end

  describe "#parseable_entries" do
    it "returns only entries with is-also" do
      entries = subject.parseable_entries
      expect(entries.all?(&:has_is_also?)).to be true
    end

    it "excludes entries without is-also" do
      entries = subject.parseable_entries
      doc_ids = entries.map(&:doc_id)
      # BCP0001, BCP0002 have no is-also
      expect(doc_ids).not_to include("BCP0001")
      expect(doc_ids).not_to include("BCP0002")
      # STD0001, STD0002 have no is-also (only title)
      expect(doc_ids).not_to include("STD0001")
      expect(doc_ids).not_to include("STD0002")
    end

    it "includes entries with is-also" do
      entries = subject.parseable_entries
      doc_ids = entries.map(&:doc_id)
      expect(doc_ids).to include("BCP0003", "BCP0004", "BCP0005", "BCP0006")
      expect(doc_ids).to include("FYI0002", "FYI0003")
      expect(doc_ids).to include("STD0003")
    end

    it "returns correct count" do
      # 4 bcp + 2 fyi + 1 std = 7
      expect(subject.parseable_entries.size).to eq 7
    end
  end

  it "parses rfc-entries" do
    expect(subject.rfc_entries.size).to eq 2
    expect(subject.rfc_entries.first.doc_id).to eq "RFC1918"
    expect(subject.rfc_entries.last.doc_id).to eq "RFC0139"
  end

  describe "empty index" do
    it "handles empty rfc-index" do
      xml = <<~XML
        <rfc-index xmlns="https://www.rfc-editor.org/rfc-index">
        </rfc-index>
      XML
      index = described_class.from_xml(xml)
      expect(index.bcp_entries).to be_nil
      expect(index.fyi_entries).to be_nil
      expect(index.std_entries).to be_nil
      expect(index.rfc_entries).to be_nil
      expect(index.subseries_entries).to eq []
      expect(index.parseable_entries).to eq []
    end
  end
end
