# frozen_string_literal: true

RSpec.describe Relaton::Ietf::Rfc::Entry do
  let(:bcp_xml) do
    <<~XML
      <bcp-entry xmlns="https://www.rfc-editor.org/rfc-index">
        <doc-id>BCP0001</doc-id>
        <stream>IETF</stream>
        <is-also>
          <doc-id>RFC0002</doc-id>
        </is-also>
      </bcp-entry>
    XML
  end

  subject { described_class.from_xml(bcp_xml) }

  describe "#entry_type" do
    it "returns bcp for BCP entry" do
      expect(subject.entry_type).to eq "bcp"
    end

    it "returns fyi for FYI entry" do
      entry = described_class.new(doc_id: "FYI0001")
      expect(entry.entry_type).to eq "fyi"
    end

    it "returns std for STD entry" do
      entry = described_class.new(doc_id: "STD0001")
      expect(entry.entry_type).to eq "std"
    end

    it "returns rfc for RFC entry" do
      entry = described_class.new(doc_id: "RFC0001")
      expect(entry.entry_type).to eq "rfc"
    end
  end

  describe "#rfc_entry?" do
    it "returns true for RFC entry" do
      entry = described_class.new(doc_id: "RFC0001")
      expect(entry.rfc_entry?).to be true
    end

    it "returns false for BCP entry" do
      expect(subject.rfc_entry?).to be false
    end
  end

  describe "#shortnum" do
    it "removes leading zeros" do
      expect(subject.shortnum).to eq "1"
    end

    it "handles larger numbers" do
      entry = described_class.new(doc_id: "BCP0123")
      expect(entry.shortnum).to eq "123"
    end

    it "handles numbers without leading zeros" do
      entry = described_class.new(doc_id: "BCP123")
      expect(entry.shortnum).to eq "123"
    end
  end

  describe "#pub_id" do
    it "returns formatted public ID for BCP" do
      expect(subject.pub_id).to eq "BCP 1"
    end

    it "returns formatted public ID for FYI" do
      entry = described_class.new(doc_id: "FYI0005")
      expect(entry.pub_id).to eq "FYI 5"
    end

    it "returns formatted public ID for STD" do
      entry = described_class.new(doc_id: "STD0010")
      expect(entry.pub_id).to eq "STD 10"
    end
  end

  describe "#anchor" do
    it "returns anchor string for BCP" do
      expect(subject.anchor).to eq "BCP1"
    end

    it "returns anchor string for FYI" do
      entry = described_class.new(doc_id: "FYI0005")
      expect(entry.anchor).to eq "FYI5"
    end

    it "returns anchor string for STD" do
      entry = described_class.new(doc_id: "STD0010")
      expect(entry.anchor).to eq "STD10"
    end
  end

  describe "#has_is_also?" do
    it "returns true when is_also has doc_ids" do
      expect(subject.has_is_also?).to be true
    end

    it "returns false when is_also is nil" do
      entry = described_class.new(doc_id: "BCP0001")
      expect(entry.has_is_also?).to be false
    end

    it "returns false when is_also has no doc_ids" do
      entry = described_class.new(
        doc_id: "BCP0001",
        is_also: Relaton::Ietf::Rfc::IsAlso.new(doc_id: []),
      )
      expect(entry.has_is_also?).to be false
    end
  end

  context "build_title" do
    it "generates BCP title" do
      title = subject.send(:build_title).first
      expect(title.content).to eq "Best Current Practice 1"
      expect(title.language).to eq "en"
      expect(title.script).to eq "Latn"
    end

    it "generates FYI title" do
      entry = described_class.new(doc_id: "FYI0001")
      title = entry.send(:build_title).first
      expect(title.content).to eq "For Your Information 1"
    end

    it "generates STD title" do
      entry = described_class.new(doc_id: "STD0001")
      title = entry.send(:build_title).first
      expect(title.content).to eq "Internet Standard technical specification 1"
    end
  end

  describe "#to_item for subseries" do
    it "returns nil when no is_also" do
      entry = described_class.new(doc_id: "BCP0001")
      expect(entry.to_item).to be_nil
    end

    it "returns nil when doc_id is nil" do
      entry = described_class.new(
        is_also: Relaton::Ietf::Rfc::IsAlso.new(doc_id: ["RFC0001"]),
      )
      expect(entry.to_item).to be_nil
    end

    it "creates Item with correct attributes" do
      item = subject.to_item
      expect(item).to be_instance_of Relaton::Ietf::ItemData
      expect(item.docnumber).to eq "BCP0001"
      expect(item.type).to eq "standard"
      expect(item.language).to eq ["en"]
      expect(item.script).to eq ["Latn"]
    end

    it "creates correct title" do
      item = subject.to_item
      title = item.title.first
      expect(title.content).to eq "Best Current Practice 1"
    end

    it "creates correct docidentifier" do
      item = subject.to_item
      docid = item.docidentifier.first
      expect(docid.type).to eq "IETF"
      expect(docid.content).to eq "BCP 1"
      expect(docid.primary).to be true
    end

    it "creates correct link" do
      item = subject.to_item
      link = item.source.first
      expect(link.type).to eq "src"
      expect(link.content.to_s).to eq "https://www.rfc-editor.org/info/bcp1"
    end

    it "creates correct formattedref" do
      item = subject.to_item
      expect(item.formattedref).to eq "BCP1"
    end

    it "creates minimal includes relations without rfc_index" do
      item = subject.to_item
      rel = item.relation.first
      expect(rel.type).to eq "includes"
      expect(rel.bibitem.docidentifier.first.content).to eq "RFC 2"
      expect(rel.bibitem.title).to eq []
    end

    it "creates full includes relations with rfc_index" do # rubocop:disable RSpec/ExampleLength
      rfc_xml = <<~XML
        <rfc-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>RFC0002</doc-id>
          <title>Host software</title>
          <author><name>B. Duvall</name></author>
          <date><month>April</month><year>1969</year></date>
          <keywords><kw>test</kw></keywords>
          <abstract><p>Example abstract.</p></abstract>
          <current-status>UNKNOWN</current-status>
          <publication-status>UNKNOWN</publication-status>
          <stream>Legacy</stream>
          <doi>10.17487/RFC0002</doi>
        </rfc-entry>
      XML
      rfc_entry = described_class.from_xml(rfc_xml)
      rfc_map = { "RFC0002" => rfc_entry }
      item = subject.to_item(rfc_map)
      rel = item.relation.first
      bibitem = rel.bibitem
      expect(rel.type).to eq "includes"
      expect(bibitem.type).to eq "standard"
      expect(bibitem.title.first.content).to eq "Host software"
      expect(bibitem.source.first.content.to_s).to include("rfc-editor.org")
      expect(bibitem.docidentifier.find { |d| d.type == "DOI" }.content).to eq "10.17487/RFC0002"
      expect(bibitem.docnumber).to eq "RFC0002"
      expect(bibitem.date.first.type).to eq "published"
      expect(bibitem.contributor).not_to be_empty
      expect(bibitem.language).to eq ["en"]
      expect(bibitem.script).to eq ["Latn"]
      expect(bibitem.abstract.first.content).to include("Example abstract")
      expect(bibitem.series).not_to be_empty
      expect(bibitem.keyword.first.taxon[0].content).to eq "test"
      expect(bibitem.ext).not_to be_nil
      expect(bibitem.ext.stream).to eq "Legacy"
      expect(bibitem.status.stage.content).to eq "UNKNOWN"
    end

    xit "serializes ext/stream in relation bibitem XML" do
      rfc_xml = <<~XML
        <rfc-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>RFC0002</doc-id>
          <title>Host software</title>
          <author><name>B. Duvall</name></author>
          <date><month>April</month><year>1969</year></date>
          <current-status>UNKNOWN</current-status>
          <publication-status>UNKNOWN</publication-status>
          <stream>Legacy</stream>
        </rfc-entry>
      XML
      rfc_entry = described_class.from_xml(rfc_xml)
      rfc_map = { "RFC0002" => rfc_entry }
      item = subject.to_item(rfc_map)
      xml_out = item.to_xml(bibdata: true)
      expect(xml_out).to include("<stream>Legacy</stream>")
    end

    it "creates series from stream" do
      item = subject.to_item
      series = item.series.first
      expect(series.type).to eq "stream"
      expect(series.title.content).to eq "IETF"
    end

    it "handles entry without stream" do
      xml = <<~XML
        <bcp-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>BCP0001</doc-id>
          <is-also>
            <doc-id>RFC0002</doc-id>
          </is-also>
        </bcp-entry>
      XML
      entry = described_class.from_xml(xml)
      item = entry.to_item
      expect(item.series).to eq []
    end

    it "handles multiple is-also references" do
      xml = <<~XML
        <bcp-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>BCP0006</doc-id>
          <is-also>
            <doc-id>RFC1930</doc-id>
            <doc-id>RFC6996</doc-id>
            <doc-id>RFC7300</doc-id>
          </is-also>
        </bcp-entry>
      XML
      entry = described_class.from_xml(xml)
      item = entry.to_item
      expect(item.relation.size).to eq 3
      expect(item.relation.map { |r| r.bibitem.docidentifier.first.content })
        .to eq ["RFC 1930", "RFC 6996", "RFC 7300"]
    end
  end

  describe "#to_item for rfc-entry" do
    let(:rfc_xml) do
      <<~XML
        <rfc-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>RFC0139</doc-id>
          <title>Echo function for ISO 8473</title>
          <author>
            <name>R.A. Hagens</name>
          </author>
          <date>
            <month>January</month>
            <year>1990</year>
          </date>
          <format>
            <file-format>ASCII</file-format>
            <file-format>HTML</file-format>
          </format>
          <page-count>6</page-count>
          <keywords>
            <kw>IPv6</kw>
            <kw>SLAAC</kw>
          </keywords>
          <abstract>
            <p>This memo defines an echo function.</p>
          </abstract>
          <obsoleted-by>
            <doc-id>RFC1574</doc-id>
            <doc-id>RFC1575</doc-id>
          </obsoleted-by>
          <is-also>
            <doc-id>BCP0026</doc-id>
          </is-also>
          <current-status>PROPOSED STANDARD</current-status>
          <publication-status>PROPOSED STANDARD</publication-status>
          <stream>IETF</stream>
          <wg_acronym>osigen</wg_acronym>
          <doi>10.17487/RFC1139</doi>
        </rfc-entry>
      XML
    end

    let(:rfc_entry) { described_class.from_xml(rfc_xml) }
    let(:item) { rfc_entry.to_item }

    it "returns an ItemData" do
      expect(item).to be_instance_of Relaton::Ietf::ItemData
    end

    it "creates correct docidentifiers" do
      ietf_id = item.docidentifier.find { |d| d.type == "IETF" }
      expect(ietf_id.content).to eq "RFC 139"
      expect(ietf_id.primary).to be true

      doi_id = item.docidentifier.find { |d| d.type == "DOI" }
      expect(doi_id.content).to eq "10.17487/RFC1139"
    end

    it "creates correct title" do
      expect(item.title.first.content).to eq "Echo function for ISO 8473"
      expect(item.title.first.type).to eq "main"
    end

    it "creates correct link" do
      expect(item.source.first.type).to eq "src"
      expect(item.source.first.content.to_s).to eq "https://www.rfc-editor.org/info/rfc139"
    end

    it "creates correct date" do
      expect(item.date.first.type).to eq "published"
      expect(item.date.first.at.to_s).to include("1990")
    end

    it "creates correct contributors" do # rubocop:disable RSpec/ExampleLength
      # Author + RFC Publisher + RFC Series + committee = 4
      expect(item.contributor.size).to eq 4

      author = item.contributor.first
      expect(author.role.first.type).to eq "author"
      expect(author.person.name.completename.content).to eq "R.A. Hagens"
      expect(author.person.name.formatted_initials).not_to be_nil

      publisher = item.contributor[1]
      expect(publisher.role.first.type).to eq "publisher"
      expect(publisher.organization.name[0].content).to eq "RFC Publisher"

      authorizer = item.contributor[2]
      expect(authorizer.role.first.type).to eq "authorizer"

      committee = item.contributor[3]
      expect(committee.role.first.type).to eq "author"
      expect(committee.role.first.description.first.content).to eq "committee"
      expect(committee.organization.abbreviation.content).to eq "IETF"
      expect(committee.organization.name[0].content).to eq "Internet Engineering Task Force"
      expect(committee.organization.subdivision.first.type).to eq "workgroup"
      expect(committee.organization.subdivision.first.identifier.first.content).to eq "osigen"
    end

    it "creates correct keywords" do
      expect(item.keyword.size).to eq 2
      expect(item.keyword[0].taxon[0].content).to eq "IPv6"
      expect(item.keyword[1].taxon[0].content).to eq "SLAAC"
    end

    it "creates correct abstract" do
      expect(item.abstract.first.content).to include("echo function")
      expect(item.abstract.first.language).to eq "en"
    end

    it "creates correct relations" do
      obsoleted = item.relation.select { |r| r.type == "obsoletedBy" }
      expect(obsoleted.size).to eq 2
      expect(obsoleted.map { |r| r.bibitem.docidentifier.first.content })
        .to eq %w[RFC1574 RFC1575]
    end

    it "creates correct status" do
      expect(item.status.stage.content).to eq "PROPOSED STANDARD"
    end

    it "creates correct series" do
      # is-also (BCP) + RFC + stream (IETF) = 3
      expect(item.series.size).to eq 3

      bcp_series = item.series.find { |s| s.title.content == "BCP" }
      expect(bcp_series.number).to eq "26"

      rfc_series = item.series.find { |s| s.title.content == "RFC" }
      expect(rfc_series.number).to eq "139"

      stream_series = item.series.find { |s| s.type == "stream" }
      expect(stream_series.title.content).to eq "IETF"
    end

    it "creates committee contributor from wg_acronym" do
      committee = item.contributor.find do |c|
        c.role.any? { |r| r.description.any? { |d| d.content == "committee" } }
      end
      expect(committee).not_to be_nil
      expect(committee.organization.subdivision.first.identifier.first.content).to eq "osigen"
    end

    it "creates correct stream in ext" do
      expect(item.ext.stream).to eq "IETF"
    end
  end

  describe "#to_item for rfc-entry without optional fields" do
    let(:minimal_rfc_xml) do
      <<~XML
        <rfc-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>RFC0001</doc-id>
          <title>Host Software</title>
          <author>
            <name>S. Crocker</name>
          </author>
          <date>
            <month>April</month>
            <year>1969</year>
          </date>
          <current-status>UNKNOWN</current-status>
          <publication-status>UNKNOWN</publication-status>
        </rfc-entry>
      XML
    end

    let(:entry) { described_class.from_xml(minimal_rfc_xml) }
    let(:item) { entry.to_item }

    it "handles missing keywords" do
      expect(item.keyword).to eq []
    end

    it "handles missing abstract" do
      expect(item.abstract).to eq []
    end

    it "handles missing relations" do
      expect(item.relation).to eq []
    end

    it "handles missing doi" do
      expect(item.docidentifier.size).to eq 1
      expect(item.docidentifier.first.type).to eq "IETF"
    end

    it "handles missing wg_acronym" do
      committee = item.contributor.find do |c|
        c.role.any? { |r| r.description.any? { |d| d.content == "committee" } }
      end
      expect(committee).to be_nil
    end

    it "handles NON WORKING GROUP wg_acronym" do
      xml = <<~XML
        <rfc-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>RFC0001</doc-id>
          <title>Host Software</title>
          <author><name>S. Crocker</name></author>
          <date><month>April</month><year>1969</year></date>
          <current-status>UNKNOWN</current-status>
          <publication-status>UNKNOWN</publication-status>
          <wg_acronym>NON WORKING GROUP</wg_acronym>
        </rfc-entry>
      XML
      e = described_class.from_xml(xml)
      committee = e.to_item.contributor.find do |c|
        c.role.any? { |r| r.description.any? { |d| d.content == "committee" } }
      end
      expect(committee).to be_nil
    end
  end

  describe "XML parsing" do
    it "parses fyi-entry" do
      xml = <<~XML
        <fyi-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>FYI0002</doc-id>
          <is-also>
            <doc-id>RFC1470</doc-id>
          </is-also>
        </fyi-entry>
      XML
      entry = described_class.from_xml(xml)
      expect(entry.doc_id).to eq "FYI0002"
      expect(entry.entry_type).to eq "fyi"
    end

    it "parses std-entry with title" do
      xml = <<~XML
        <std-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>STD0003</doc-id>
          <title>Requirements for Internet Hosts</title>
          <is-also>
            <doc-id>RFC1122</doc-id>
            <doc-id>RFC1123</doc-id>
          </is-also>
        </std-entry>
      XML
      entry = described_class.from_xml(xml)
      expect(entry.doc_id).to eq "STD0003"
      expect(entry.title).to eq "Requirements for Internet Hosts"
      expect(entry.is_also.doc_id).to eq ["RFC1122", "RFC1123"]
    end

    it "parses rfc-entry" do
      xml = <<~XML
        <rfc-entry xmlns="https://www.rfc-editor.org/rfc-index">
          <doc-id>RFC0139</doc-id>
          <title>Echo function for ISO 8473</title>
          <author><name>R.A. Hagens</name></author>
          <date><month>January</month><year>1990</year></date>
          <current-status>PROPOSED STANDARD</current-status>
          <publication-status>PROPOSED STANDARD</publication-status>
          <doi>10.17487/RFC1139</doi>
        </rfc-entry>
      XML
      entry = described_class.from_xml(xml)
      expect(entry.doc_id).to eq "RFC0139"
      expect(entry.entry_type).to eq "rfc"
      expect(entry.rfc_entry?).to be true
      expect(entry.author.first.name).to eq "R.A. Hagens"
      expect(entry.date.first.month).to eq "January"
      expect(entry.date.first.year).to eq "1990"
      expect(entry.doi).to eq "10.17487/RFC1139"
    end
  end
end
