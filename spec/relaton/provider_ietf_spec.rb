require "jing"

RSpec.describe Relaton::Provider::Ietf do
  subject do
    xml = File.read "spec/examples/rfc.xml"
    Relaton::Provider::Ietf.from_rfcxml xml
  end

  it "returns an item" do
    expect(subject).to be_instance_of RelatonIetf::IetfBibliographicItem
  end

  it "returns xml" do
    file = "spec/examples/rfc_xml.xml"
    xml = subject.to_xml bibdata: true
    File.write file, xml unless File.exist? file
    expect(xml).to be_equivalent_to File.read(file).
      sub(/(?<=fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    schema = Jing.new "spec/examples/isobib.rng"
    errors = schema.validate file
    expect(errors).to eq []
  end
end
