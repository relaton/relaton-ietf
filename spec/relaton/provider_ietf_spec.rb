RSpec.describe Relaton::Provider::Ietf do
  subject do
    xml = File.read "spec/fixtures/rfc.xml"
    described_class.from_rfcxml xml
  end

  xit "returns an item" do
    expect(subject).to be_instance_of Relaton::Ietf::ItemData
  end

  xit "returns xml" do
    file = "spec/examples/rfc_xml.xml"
    xml = subject.to_xml bibdata: true
    File.write file, xml unless File.exist? file
    expect(xml).to be_equivalent_to File.read(file)
      .sub(/(?<=fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    schema = Jing.new "grammars/relaton-ietf-compile.rng"
    errors = schema.validate file
    expect(errors).to eq []
  end
end
