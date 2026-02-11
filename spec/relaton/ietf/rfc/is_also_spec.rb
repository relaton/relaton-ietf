# frozen_string_literal: true

RSpec.describe Relaton::Ietf::Rfc::IsAlso do
  it "parses single doc-id" do
    xml = <<~XML
      <is-also xmlns="https://www.rfc-editor.org/rfc-index">
        <doc-id>RFC1930</doc-id>
      </is-also>
    XML
    is_also = described_class.from_xml(xml)
    expect(is_also.doc_id).to eq ["RFC1930"]
  end

  it "parses multiple doc-ids" do
    xml = <<~XML
      <is-also xmlns="https://www.rfc-editor.org/rfc-index">
        <doc-id>RFC1930</doc-id>
        <doc-id>RFC6996</doc-id>
        <doc-id>RFC7300</doc-id>
      </is-also>
    XML
    is_also = described_class.from_xml(xml)
    expect(is_also.doc_id).to eq ["RFC1930", "RFC6996", "RFC7300"]
  end

  it "handles empty is-also" do
    xml = <<~XML
      <is-also xmlns="https://www.rfc-editor.org/rfc-index">
      </is-also>
    XML
    is_also = described_class.from_xml(xml)
    expect(is_also.doc_id).to be_nil
  end
end
