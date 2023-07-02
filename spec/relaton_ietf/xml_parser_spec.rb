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
end
