RSpec.describe RelatonIetf::RfcIndexEntry do
  context "create instance" do
    let(:doc) { double "doc", name: "bcp-entry" }
    let(:doc_id) { double "doc_id", text: "RFC0001" }
    let(:adid) { double "adid", text: "RFC0002" }

    it "return instance" do
      expect(RelatonIetf::RfcIndexEntry).to receive(:new)
        .with("bcp", "RFC0001", ["RFC0002"]).and_return(:parser)
      expect(doc).to receive(:at).with("./xmlns:doc-id").and_return(doc_id)
      expect(doc).to receive(:xpath).with("./xmlns:is-also/xmlns:doc-id").and_return([adid])
      expect(RelatonIetf::RfcIndexEntry.parse(doc)).to eq :parser
    end

    it "return nil if doc-id not found" do
      expect(RelatonIetf::RfcIndexEntry).not_to receive(:new)
      expect(doc).to receive(:at).with("./xmlns:doc-id").and_return(nil)
      expect(doc).to receive(:xpath).with("./xmlns:is-also/xmlns:doc-id").and_return([adid])
      expect(RelatonIetf::RfcIndexEntry.parse(doc)).to eq nil
    end

    it "return nil if is-also not found" do
      expect(RelatonIetf::RfcIndexEntry).not_to receive(:new)
      expect(doc).to receive(:at).with("./xmlns:doc-id").and_return(doc_id)
      expect(doc).to receive(:xpath).with("./xmlns:is-also/xmlns:doc-id").and_return([])
      expect(RelatonIetf::RfcIndexEntry.parse(doc)).to eq nil
    end
  end

  it "initialize" do
    subj = RelatonIetf::RfcIndexEntry.new "bcp", "RFC0001", ["RFC0002"]
    expect(subj.instance_variable_get(:@name)).to eq "bcp"
    expect(subj.instance_variable_get(:@shortnum)).to eq "1"
    expect(subj.instance_variable_get(:@doc_id)).to eq "RFC0001"
    expect(subj.instance_variable_get(:@is_also)).to eq ["RFC0002"]
  end

  context "instance methods" do
    subject { RelatonIetf::RfcIndexEntry.new "bcp", "RFC0001", ["RFC0002"] }

    it "docnumber" do
      expect(subject.docnumber).to eq "RFC0001"
    end

    it "to_xml" do
      expect(subject.to_xml).to be_equivalent_to <<~XML
        <referencegroup xmlns:xi="http://www.w3.org/2001/XInclude" anchor="BCP1" target="https://www.rfc-editor.org/info/bcp1">
          <xi:include href="https://www.rfc-editor.org/refs/bibxml/reference.RFC.0002.xml"/>
        </referencegroup>
      XML
    end
  end
end
