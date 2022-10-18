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

      it "with organization as author" do
        idx = Nokogiri::XML <<~XML
          <rfc-index xmlns="http://www.rfc-editor.org/rfc-index">
            <rfc-entry>
              <author><name>IAB</name></author>
            </rfc-entry>
          </rfc-index>
        XML
        rfcdoc = idx.at "/xmlns:rfc-index/xmlns:rfc-entry"
        subj = RelatonIetf::RfcEntry.new rfcdoc
        contr = subj.parse_contributor
        expect(contr).to be_instance_of Array
        expect(contr.size).to be 1
        expect(contr[0]).to be_instance_of RelatonBib::ContributionInfo
        expect(contr[0].role[0].type).to eq "author"
        expect(contr[0].entity).to be_instance_of RelatonBib::Organization
        expect(contr[0].entity.name[0].content).to eq "IAB"
      end

      shared_examples "parse_org" do |name|
        let(:ref) do
          doc = Nokogiri::XML <<~XML
            <rfc-index xmlns="http://www.rfc-editor.org/rfc-index">
              <rfc-entry>
                <author>
                  <name>#{name}</name>
                </author>
              </rfc-entry>
            </rfc-index>
          XML
          doc.at "/xmlns:rfc-index/xmlns:rfc-entry"
        end

        it "parse organization #{name}" do
          rfcentry = described_class.new ref
          contrib = rfcentry.parse_contributor
          expect(contrib[0].entity).to be_instance_of RelatonBib::Organization
          expect(contrib[0].entity.name[0].content).to eq name
        end
      end

      it_behaves_like "parse_org", "Network Information Center. Stanford Research Institute"
      it_behaves_like "parse_org", "Information Sciences Institute University of Southern California"
      it_behaves_like "parse_org", "International Telegraph and Telephone Consultative Committee of the International Telecommunication Union"
      it_behaves_like "parse_org", "National Bureau of Standards"
      it_behaves_like "parse_org", "International Organization for Standardization"
      it_behaves_like "parse_org", "National Research Council"
      it_behaves_like "parse_org", "Gateway Algorithms and Data Structures Task Force"
      it_behaves_like "parse_org", "National Science Foundation"
      it_behaves_like "parse_org", "Network Technical Advisory Group"
      it_behaves_like "parse_org", "NetBIOS Working Group in the Defense Advanced Research Projects Agency"
      it_behaves_like "parse_org", "Internet Activities Board"
      it_behaves_like "parse_org", "End-to-End Services Task Force"
      it_behaves_like "parse_org", "Defense Advanced Research Projects Agency"
      it_behaves_like "parse_org", "The North American Directory Forum"
      it_behaves_like "parse_org", "ESCC X.500/X.400 Task Force"
      it_behaves_like "parse_org", "ESnet Site Coordinating Comittee (ESCC)"
      it_behaves_like "parse_org", "Energy Sciences Network (ESnet)"
      it_behaves_like "parse_org", "Internet Engineering Steering Group"
      it_behaves_like "parse_org", "RARE WG-MSG Task Force 88"
      it_behaves_like "parse_org", "Internet Assigned Numbers Authority (IANA)"
      it_behaves_like "parse_org", "Federal Networking Council"
      it_behaves_like "parse_org", "Audio-Video Transport Working Group"
      it_behaves_like "parse_org", "KOI8-U Working Group"
      it_behaves_like "parse_org", "The Internet Society"
      it_behaves_like "parse_org", "Sun Microsystems"

      shared_examples "parse_person" do |fullname, inits, sname|
        let(:ref) do
          doc = Nokogiri::XML <<~XML
            <rfc-index xmlns="http://www.rfc-editor.org/rfc-index">
              <rfc-entry>
                <author>
                  <name>#{fullname}</name>
                </author>
              </rfc-entry>
            </rfc-index>
          XML
          doc.at "/xmlns:rfc-index/xmlns:rfc-entry"
        end

        it "parse person #{fullname}" do
          rfcentry = described_class.new ref
          contrib = rfcentry.parse_contributor
          expect(contrib[0].entity).to be_instance_of RelatonBib::Person
          expect(contrib[0].entity.name.completename.content).to eq fullname
          expect(contrib[0].entity.name.initials.content).to eq inits
          expect(contrib[0].entity.name.surname.content).to eq sname
        end
      end

      it_behaves_like "parse_person", "M. St. Johns", "M.", "St. Johns"
      it_behaves_like "parse_person", "T. LaQuey Parker", "T.", "LaQuey Parker"
      it_behaves_like "parse_person", "A. Lyman Chapin", "A.", "Lyman Chapin"
      it_behaves_like "parse_person", "D. Eastlake 3rd", "D.", "Eastlake 3rd"
      it_behaves_like "parse_person", "E. van der Poel", "E.", "van der Poel"
      it_behaves_like "parse_person", "P. Nesser III", "P.", "Nesser III"
      it_behaves_like "parse_person", "G. J. de Groot", "G. J.", "de Groot"
      it_behaves_like "parse_person", "F. Ching Liaw", "F.", "Ching Liaw"
      it_behaves_like "parse_person", "J. De Winter", "J.", "De Winter"
      it_behaves_like "parse_person", "J. C. Mogul", "J. C.", "Mogul"
      it_behaves_like "parse_person", "J. Le Boudec", "J.", "Le Boudec"
      it_behaves_like "parse_person", "K. de Graaf", "K.", "de Graaf"
      it_behaves_like "parse_person", "J. G. Myers", "J. G.", "Myers"
      it_behaves_like "parse_person", "G. de Groot", "G.", "de Groot"
      it_behaves_like "parse_person", "K. van den Hout", "K.", "van den Hout"
      it_behaves_like "parse_person", "D. van Gulik", "D.", "van Gulik"
      it_behaves_like "parse_person", "F. Le Faucheur", "F.", "Le Faucheur"
      it_behaves_like "parse_person", "F. da Cruz", "F.", "da Cruz"
      it_behaves_like "parse_person", "T. Murphy Jr.", "T.", "Murphy Jr."
      it_behaves_like "parse_person", "J. Hadi Salim", "J.", "Hadi Salim"
      it_behaves_like "parse_person", "C. de Laat", "C.", "de Laat"
      it_behaves_like "parse_person", "B. de Bruijn", "B.", "de Bruijn"
      it_behaves_like "parse_person", "P. St. Pierre", "P.", "St. Pierre"
      it_behaves_like "parse_person", "S. De Cnodder", "S.", "De Cnodder"
      it_behaves_like "parse_person", "D. Del Torto", "D.", "Del Torto"
      it_behaves_like "parse_person", "P. De Schrijver", "P.", "De Schrijver"
      it_behaves_like "parse_person", "A. van Hoff", "A.", "van Hoff"
      it_behaves_like "parse_person", "J.C.R. Bennet", "J.C.R.", "Bennet"
      it_behaves_like "parse_person", "J.Y. Le Boudec", "J.Y.", "Le Boudec"
      it_behaves_like "parse_person", "A. B. Roach", "A. B.", "Roach"
      it_behaves_like "parse_person", "A. De La Cruz", "A.", "De La Cruz"
      it_behaves_like "parse_person", "R. P. Swale", "R. P.", "Swale"
      it_behaves_like "parse_person", "P. A. Mart", "P. A.", "Mart"
      it_behaves_like "parse_person", "A. van Wijk", "A.", "van Wijk"
      it_behaves_like "parse_person", "K. El Malki", "K.", "El Malki"
      it_behaves_like "parse_person", "C. Du Laney", "C.", "Du Laney"
      it_behaves_like "parse_person", "Y. El Mghazli", "Y.", "El Mghazli"
      it_behaves_like "parse_person", "J. Van Dyke", "J.", "Van Dyke"
      it_behaves_like "parse_person", "H. van der Linde", "H.", "van der Linde"
      it_behaves_like "parse_person", "H. Van de Sompel", "H.", "Van de Sompel"
      it_behaves_like "parse_person", "A. L. N. Reddy", "A. L. N.", "Reddy"
      it_behaves_like "parse_person", "J.L. Le Roux", "J.L.", "Le Roux"
      it_behaves_like "parse_person", "J. De Clercq", "J.", "De Clercq"
      it_behaves_like "parse_person", "M. Rahman", "M.", "Rahman"
      it_behaves_like "parse_person", "Y. Kim", "Y.", "Kim"
      it_behaves_like "parse_person", "M. Dos Santos", "M.", "Dos Santos"
      it_behaves_like "parse_person", "N. Del Regno", "N.", "Del Regno"
      it_behaves_like "parse_person", "J. de Oliveira", "J.", "de Oliveira"
      it_behaves_like "parse_person", "G. Van de Velde", "G.", "Van de Velde"
      it_behaves_like "parse_person", "CY. Lee", "CY.", "Lee"
      it_behaves_like "parse_person", "J.-L. Le Roux", "J.-L.", "Le Roux"
      it_behaves_like "parse_person", "B. de hOra", "B.", "de hOra"
      it_behaves_like "parse_person", "JP. Vasseur", "JP.", "Vasseur"
      it_behaves_like "parse_person", "B. Van Lieu", "B.", "Van Lieu"
      it_behaves_like "parse_person", "I. van Beijnum", "I.", "van Beijnum"
      it_behaves_like "parse_person", "A.J. Elizondo Armengol", "A.J.", "Elizondo Armengol"
      it_behaves_like "parse_person", "A. Jerman Blazic", "A.", "Jerman Blazic"
      it_behaves_like "parse_person", "T. Van Caenegem", "T.", "Van Caenegem"
      it_behaves_like "parse_person", "B. Ver Steeg", "B.", "Ver Steeg"
      it_behaves_like "parse_person", "H. van Helvoort", "H.", "van Helvoort"
      it_behaves_like "parse_person", "L. Hornquist Astrand", "L.", "Hornquist Astrand"
      it_behaves_like "parse_person", "JL. Le Roux", "JL.", "Le Roux"
      it_behaves_like "parse_person", "AM. Eklund Lowinder", "AM.", "Eklund Lowinder"
      it_behaves_like "parse_person", "S P. Romano", "S P.", "Romano"
      it_behaves_like "parse_person", "R. van Rein", "R.", "van Rein"
      it_behaves_like "parse_person", "M.A. Reina Ortega", "M.A.", "Reina Ortega"
      it_behaves_like "parse_person", "H. M.-H. Liu", "H. M.-H.", "Liu"
      it_behaves_like "parse_person", "A. de la Oliva", "A.", "de la Oliva"
      it_behaves_like "parse_person", "JC. Zúñiga", "JC.", "Zúñiga"
      it_behaves_like "parse_person", "D.C. Medway Gash", "D.C.", "Medway Gash"
      it_behaves_like "parse_person", "D. von Hugo", "D.", "von Hugo"
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
