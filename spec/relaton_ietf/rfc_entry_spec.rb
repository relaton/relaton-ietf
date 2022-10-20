RSpec.describe RelatonIetf::RfcEntry do
  it "create instance and parse" do
    parser = double "parser"
    expect(parser).to receive(:parse).and_return(:bibitem)
    expect(RelatonIetf::RfcEntry).to receive(:new).with(:doc).and_return parser
    expect(RelatonIetf::RfcEntry.parse(:doc)).to be :bibitem
  end

  context "instance methods" do
    let(:doc) do
      idx = Nokogiri::XML File.read "spec/examples/ietf_rfcsubseries.xml", encoding: "UTF-8"
      idx.at "/xmlns:rfc-index/xmlns:rfc-entry"
    end

    subject { RelatonIetf::RfcEntry.new(doc) }

    it "initialize" do
      expect(subject).to be_instance_of RelatonIetf::RfcEntry
      expect(subject.instance_variable_get(:@doc)).to be doc
    end

    it "parse doc" do
      expect(subject).to receive(:parse_docid)
      expect(subject).to receive(:code).twice
      expect(subject).to receive(:parse_title)
      expect(subject).to receive(:parse_link)
      expect(subject).to receive(:parse_date)
      expect(subject).to receive(:parse_contributor)
      expect(subject).to receive(:parse_keyword)
      expect(subject).to receive(:parse_abstract)
      expect(subject).to receive(:parse_relation)
      expect(subject).to receive(:parse_status)
      expect(subject).to receive(:parse_editorialgroup)
      expect(RelatonIetf::IetfBibliographicItem).to receive(:new).and_return :bib
      expect(subject.parse).to be :bib
    end

    it "parse docid" do
      did = subject.parse_docid
      expect(did).to be_instance_of Array
      expect(did.size).to be 2
      expect(did[0]).to be_instance_of RelatonBib::DocumentIdentifier
      expect(did[0].type).to eq "IETF"
      expect(did[0].id).to eq "RFC 139"
      expect(did[0].primary).to be true
      expect(did[1].type).to eq "DOI"
      expect(did[1].id).to eq "10.17487/RFC1139"
    end

    it "parse title" do
      title = subject.parse_title
      expect(title).to be_instance_of Array
      expect(title.size).to be 1
      expect(title[0]).to be_instance_of RelatonBib::TypedTitleString
      expect(title[0].type).to eq "main"
      expect(title[0].title.content).to eq "Echo function for ISO 8473"
    end

    it "parse link" do
      link = subject.parse_link
      expect(link).to be_instance_of Array
      expect(link.size).to be 1
      expect(link[0]).to be_instance_of RelatonBib::TypedUri
      expect(link[0].type).to eq "src"
      expect(link[0].content.to_s).to eq "https://www.rfc-editor.org/info/rfc139"
    end

    it "parse date" do
      date = subject.parse_date
      expect(date).to be_instance_of Array
      expect(date.size).to be 1
      expect(date[0]).to be_instance_of RelatonBib::BibliographicDate
      expect(date[0].type).to eq "published"
      expect(date[0].on).to eq "1990-01"
    end

    context "parse contributor" do
      it do
        contr = subject.parse_contributor
        expect(contr).to be_instance_of Array
        expect(contr.size).to be 1
        expect(contr[0]).to be_instance_of RelatonBib::ContributionInfo
        expect(contr[0].role[0].type).to eq "author"
        expect(contr[0].entity).to be_instance_of RelatonBib::Person
        expect(contr[0].entity.name.completename.content).to eq "R.A. Hagens"
      end
    end

    context "parse role" do
      it "when role is not defined" do
        contrib = double "contrib"
        expect(contrib).to receive(:at).with("./xmlns:title").and_return nil
        expect(subject.parse_role(contrib)).to eq [{ type: "author" }]
      end

      it "when role is defined" do
        contrib = double "contrib"
        title = double "title", text: "Editor"
        expect(contrib).to receive(:at).with("./xmlns:title").and_return title
        expect(subject.parse_role(contrib)).to eq [{ type: "editor" }]
      end
    end

    it "parse keyword" do
      kw = subject.parse_keyword
      expect(kw).to be_instance_of Array
      expect(kw.size).to be 4
      expect(kw[0]).to eq "IPv6"
    end

    it "parse abstract" do
      abs = subject.parse_abstract
      expect(abs).to be_instance_of Array
      expect(abs.size).to be 1
      expect(abs[0]).to be_instance_of RelatonBib::FormattedString
      expect(abs[0].content).to include "This memo defines an echo function"
    end

    it "parse relation" do
      rel = subject.parse_relation
      expect(rel).to be_instance_of Array
      expect(rel.size).to be 2
      expect(rel[0]).to be_instance_of RelatonBib::DocumentRelation
      expect(rel[0].type).to eq "obsoletedBy"
      expect(rel[0].bibitem.formattedref.content).to eq "RFC1574"
      expect(rel[0].bibitem.docidentifier[0].id).to eq "RFC1574"
      expect(rel[0].bibitem.docidentifier[0].type).to eq "IETF"
      expect(rel[0].bibitem.docidentifier[0].primary).to be true
    end

    it "parse status" do
      expect(subject.parse_status.stage.value).to eq "PROPOSED STANDARD"
    end

    it "parse series" do
      ser = subject.parse_series
      expect(ser).to be_instance_of Array
      expect(ser.size).to be 2
      expect(ser[0]).to be_instance_of RelatonBib::Series
      expect(ser[0].title.title.content).to eq "BCP"
      expect(ser[0].number).to eq "26"
      expect(ser[1].title.title.content).to eq "RFC"
      expect(ser[1].number).to eq "139"
    end

    it "parse editorialgroup" do
      eg = subject.parse_editorialgroup
      expect(eg).to be_instance_of RelatonBib::EditorialGroup
      expect(eg.technical_committee[0].workgroup.name).to eq "osigen"
    end

    context "parse initials" do
      it "with periods" do
        inits = subject.forename "A.B."
        expect(inits).to be_instance_of Array
        expect(inits.size).to be 2
        expect(inits[0]).to be_instance_of RelatonBib::Forename
        expect(inits[0].initial).to eq "A"
        expect(inits[1].initial).to eq "B"
      end

      it "with space" do
        inits = subject.forename "A B"
        expect(inits.size).to be 2
        expect(inits[0].initial).to eq "A"
        expect(inits[1].initial).to eq "B"
      end

      it "with periods and space" do
        inits = subject.forename "A. B."
        expect(inits.size).to be 2
        expect(inits[0].initial).to eq "A"
        expect(inits[1].initial).to eq "B"
      end

      it "with space and period" do
        inits = subject.forename "A B."
        expect(inits.size).to be 2
        expect(inits[0].initial).to eq "A"
        expect(inits[1].initial).to eq "B"
      end
    end
  end

  it "skip NON WORKING GROUP" do
    doc = Nokogiri::XML <<~XML
      <rfc-index xmlns="http://www.rfc-editor.org/rfc-index">
        <rfc-entry>
          <wg_acronym>NON WORKING GROUP</wg_acronym>
        </rfc-entry>
      </rfc-index>
    XML
    rfc_entry = RelatonIetf::RfcEntry.new doc.at("/xmlns:rfc-index/xmlns:rfc-entry")
    expect(rfc_entry.parse_editorialgroup).to be_nil
  end
end
