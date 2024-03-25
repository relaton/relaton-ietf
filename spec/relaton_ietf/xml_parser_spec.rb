describe RelatonIetf::XMLParser do
  let(:xml) do
    <<-XML
      <bibitem type="standard">
        <docidentifier type="IETF">RFC0001</docidentifier>
        <ext>
          <stream>IETF</stream>
        </ext>
      </bibitem>
    XML
  end

  it "parse" do
    bib = RelatonIetf::XMLParser.from_xml xml
    expect(bib).to be_instance_of RelatonIetf::IetfBibliographicItem
    expect(bib.docidentifier.first.id).to eq "RFC0001"
    expect(bib.stream).to eq "IETF"
  end

  it "create_doctype" do
    node = double(text: "rfc")
    expect(node).to receive(:[]).with(:abbreviation).and_return("RFC")
    dt = described_class.send(:create_doctype, node)
    expect(dt).to be_instance_of RelatonIetf::DocumentType
    expect(dt.type).to eq "rfc"
    expect(dt.abbreviation).to eq "RFC"
  end
end
