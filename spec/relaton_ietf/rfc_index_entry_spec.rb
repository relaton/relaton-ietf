RSpec.describe RelatonIetf::RfcIndexEntry do
  context "create instance" do
    let(:doc) { double "doc", name: "bcp-entry" }
    let(:doc_id) { double "doc_id", text: "RFC0001" }
    let(:adid) { double "adid", text: "RFC0002" }

    it "create and run parser" do
      parser = double "parser"
      expect(parser).to receive(:parse).and_return(:bibitem)
      expect(RelatonIetf::RfcIndexEntry).to receive(:new)
        .with(doc, "RFC0001", ["RFC0002"]).and_return(parser)
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
    idx = Nokogiri::XML <<-XML
      <rfc-index xmlns="http://www.rfc-editor.org/rfc-index">
        <bcp-entry>
          <doc-id>BCP0006</doc-id>
          <is-also>
            <doc-id>RFC1930</doc-id>
            <doc-id>RFC6996</doc-id>
            <doc-id>RFC7300</doc-id>
          </is-also>
        </bcp-entry>
      </rfc-index>
    XML
    doc = idx.at "/xmlns:rfc-index/xmlns:bcp-entry"
    subj = RelatonIetf::RfcIndexEntry.new doc, "RFC0001", ["RFC0002"]
    expect(subj.instance_variable_get(:@name)).to eq "bcp"
    expect(subj.instance_variable_get(:@shortnum)).to eq "1"
    expect(subj.instance_variable_get(:@doc_id)).to eq "RFC0001"
    expect(subj.instance_variable_get(:@is_also)).to eq ["RFC0002"]
  end

  context "instance methods" do
    let(:doc) { double "doc", name: "bcp-entry" }

    subject { RelatonIetf::RfcIndexEntry.new doc, "BCP0001", ["RFC0002"] }

    it "parse" do
      date = double "date"
      expect(date).to receive(:to_s).and_return("2018-01-01")
      expect(Date).to receive(:today).and_return(date)
      expect(subject).to receive(:make_title)
      expect(subject).to receive(:docnumber)
      expect(subject).to receive(:parse_docid)
      expect(subject).to receive(:parse_link)
      expect(subject).to receive(:formattedref)
      expect(subject).to receive(:parse_relation)
      expect(RelatonIetf::IetfBibliographicItem).to receive(:new).and_return(:bibitem)
      expect(subject.parse).to be :bibitem
    end

    context "make_title" do
      it "BCP" do
        title = subject.make_title
        expect(title).to be_instance_of Array
        expect(title.length).to eq 1
        expect(title.first).to be_instance_of RelatonBib::TypedTitleString
        expect(title.first.title.content).to eq "Best Current Practice 1"
      end

      it "FYI" do
        subject.instance_variable_set :@name, "fyi"
        title = subject.make_title
        expect(title.first.title.content).to eq "For Your Information 1"
      end

      it "STD" do
        subject.instance_variable_set :@name, "std"
        title = subject.make_title
        expect(title.first.title.content).to eq "Internet Standard technical specification 1"
      end
    end

    it "docnumber" do
      expect(subject.docnumber).to eq "BCP0001"
    end

    it "parse docid" do
      expect(RelatonBib::DocumentIdentifier).to receive(:new)
        .with(type: "IETF", id: "BCP 1", primary: true).and_return(:id)
      expect(subject.parse_docid).to eq %i[id]
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
      rels = subject.parse_relation
      expect(rels).to be_instance_of Array
      expect(rels.size).to eq 1
      expect(rels.first).to be_instance_of Hash
      expect(rels.first[:bibitem]).to be_instance_of RelatonIetf::IetfBibliographicItem
      expect(rels.first[:bibitem].docidentifier.first.id).to eq "RFC 2"
    end
  end
end
