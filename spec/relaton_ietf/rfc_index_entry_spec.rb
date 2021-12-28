RSpec.describe RelatonIetf::RfcIndexEntry do
  context "create instance" do
    let(:doc) { double "doc", name: "bcp-entry" }
    let(:doc_id) { double "doc_id", text: "RFC0001" }
    let(:adid) { double "adid", text: "RFC0002" }

    it "create and run parser" do
      parser = double "parser"
      expect(parser).to receive(:parse).and_return(:bibitem)
      expect(RelatonIetf::RfcIndexEntry).to receive(:new)
        .with("bcp", "RFC0001", ["RFC0002"]).and_return(parser)
      expect(doc).to receive(:at).with("./xmlns:doc-id").and_return(doc_id)
      expect(doc).to receive(:xpath).with("./xmlns:is-also/xmlns:doc-id").and_return([adid])
      expect(RelatonIetf::RfcIndexEntry.parse(doc)).to eq :bibitem
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

    it "parse" do
      expect(subject).to receive(:docnumber)
      expect(subject).to receive(:parse_docid)
      expect(subject).to receive(:parse_link)
      expect(subject).to receive(:formattedref)
      expect(subject).to receive(:parse_relation)
      expect(RelatonIetf::IetfBibliographicItem).to receive(:new).and_return(:bibitem)
      expect(subject.parse).to be :bibitem
    end

    it "docnumber" do
      expect(subject.docnumber).to eq "RFC0001"
    end

    it "parse docid" do
      expect(RelatonBib::DocumentIdentifier).to receive(:new)
        .with(type: "IETF", scope: "anchor", id: "BCP1").and_return(:id1)
      expect(subject.parse_docid).to eq %i[id1]
    end

    it "parse link" do
      expect(RelatonBib::TypedUri).to receive(:new)
        .with(type: "src", content: "https://www.rfc-editor.org/info/bcp1").and_return(:uri)
      expect(subject.parse_link).to eq [:uri]
    end

    it "formattedref" do
      expect(RelatonBib::FormattedRef).to receive(:new)
        .with(content: "BCP1", language: "en", script: "Latn")
        .and_return(:formattedref)
      expect(subject.formattedref).to be :formattedref
    end

    it "parse relation" do
      expect(RelatonIetf::IetfBibliography).to receive(:get).with("RFC 0002").and_return(:bibitem)
      expect(subject.parse_relation).to eq [{ bibitem: :bibitem, type: "includes" }]
    end
  end
end
