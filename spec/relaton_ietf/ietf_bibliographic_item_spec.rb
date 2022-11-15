RSpec.describe RelatonIetf::IetfBibliographicItem do
  it "warn if doctype is invalid" do
    expect do
      described_class.new doctype: "type"
    end.to output(/invalid doctype type/).to_stderr
  end

  it "don't render date if IANA" do
    docid = RelatonBib::DocumentIdentifier.new(type: "IANA", id: "IANA 123")
    bibxml = described_class.new(
      docid: [docid], date: [{ on: "2000-01-01", type: "published" }],
    ).to_bibxml
    expect(bibxml).not_to include "date"
  end
end
