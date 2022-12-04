RSpec.describe RelatonIetf::HashConverter do
  it "creates IetfBibliographicItem form hash" do
    hash = YAML.load_file "spec/examples/ietf_bib_item.yml"
    item = RelatonIetf::IetfBibliographicItem.from_hash hash
    xml = item.to_xml(bibdata: true)
    file = "spec/examples/from_yaml.xml"
    File.write file, xml, encoding: "UTF-8" unless File.exist? file
    expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
    schema = Jing.new "grammars/relaton-ietf-compile.rng"
    errors = schema.validate file
    expect(errors).to eq []
  end
end
