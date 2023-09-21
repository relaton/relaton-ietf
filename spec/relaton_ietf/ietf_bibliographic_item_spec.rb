RSpec.describe RelatonIetf::IetfBibliographicItem do
  it "warn if doctype is invalid" do
    expect do
      described_class.new doctype: "type"
    end.to output(/\[relaton-ietf\] WARNING: invalid doctype `type`/).to_stderr
  end

  context "render BibXML" do
    it "don't render date if IANA" do
      docid = RelatonBib::DocumentIdentifier.new(type: "IANA", id: "IANA 123")
      bibxml = described_class.new(
        docid: [docid], date: [{ on: "2000-01-01", type: "published" }],
      ).to_bibxml
      expect(bibxml).not_to include "date"
    end

    it "render date if not IANA" do
      docid = RelatonBib::DocumentIdentifier.new(type: "IETF", id: "RFC 123")
      bibxml = described_class.new(
        docid: [docid], date: [{ on: "2000-01-01", type: "published" }],
      ).to_bibxml
      expect(bibxml).to include "date"
    end

    it "don't render contributor RFC Publisher" do
      org = RelatonBib::Organization.new(name: "RFC Publisher")
      role = { type: "publisher" }
      rfc_publisher = RelatonBib::ContributionInfo.new entity: org, role: [role]
      docid = RelatonBib::DocumentIdentifier.new(type: "IETF", id: "RFC 123")
      item = described_class.new docid: [docid], contributor: [rfc_publisher]
      bibxml = item.to_bibxml
      expect(bibxml).not_to include "author"
    end

    it "render not RFC Publisher contributor" do
      org = RelatonBib::Organization.new(name: "RFC Series")
      role = { type: "publisher" }
      rfc_publisher = RelatonBib::ContributionInfo.new entity: org, role: [role]
      docid = RelatonBib::DocumentIdentifier.new(type: "IETF", id: "RFC 123")
      item = described_class.new docid: [docid], contributor: [rfc_publisher]
      bibxml = item.to_bibxml
      expect(bibxml).to include "author"
    end
  end

  context "render" do
    subject do
      docid = RelatonBib::DocumentIdentifier.new(type: "IETF", id: "RFC 123")
      described_class.new(doctype: "RFC", stream: "IETF", docid: [docid])
    end

    it "to_hash" do
      expect(subject.to_hash).to eq(
        "docid" => [{ "id" => "RFC 123", "type" => "IETF" }], "doctype" => "RFC",
        "ext" => { "schema-version" => "v1.0.1", "stream" => "IETF" },
        "id" => "RFC123", "schema-version" => "v1.2.4"
      )
    end

    it "to_xml" do
      expect(subject.to_xml(bibdata: true)).to be_equivalent_to <<~XML
        <bibdata schema-version="v1.2.4">
          <docidentifier type="IETF">RFC 123</docidentifier>
          <ext schema-version="v1.0.1">
            <doctype>RFC</doctype>
            <stream>IETF</stream>
          </ext>
        </bibdata>
      XML
    end
  end
end
