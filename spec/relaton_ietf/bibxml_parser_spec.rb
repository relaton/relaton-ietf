describe RelatonIetf::BibXMLParser do
  context "pubid_type" do
    context "returns RFC" do
      it { expect(described_class.pubid_type("RFC 1234")).to eq "RFC" }
      it { expect(described_class.pubid_type("BCP 1234")).to eq "RFC" }
      it { expect(described_class.pubid_type("FYI 1234")).to eq "RFC" }
      it { expect(described_class.pubid_type("STD 1234")).to eq "RFC" }
    end

    it "internet-draft" do
      expect(described_class.pubid_type("I-D 1234")).to eq "Internet-Draft"
    end
  end

  context "parse surname, initials, and forename" do
    it "without fullname" do
      result = described_class.parse_surname_initials nil, "Smith", "J."
      expect(result).to eq ["Smith", "J.", nil]
    end

    it do
      doc = Nokogiri::XML <<~XML
        <reference anchor="RFC1234">
          <front>
            <author initials="J." surname="Reschke" fullname="Julian Reschke" />
          </front>
        </reference>
      XML
      ref = doc.at "/reference"
      person = described_class.person ref.at("./front/author"), ref
      expect(person.name.completename.content).to eq "Julian Reschke"
    end
  end

  context "skip empty person" do
    let(:doc) do
      doc = Nokogiri::XML <<~XML
        <reference anchor="RFC1234" target="https://www.rfc-editor.org/info/rfc1234">
          <front>
            <author initials="" surname="None" fullname="None"/>
          </front>
        </reference>
      XML
      doc.at "/reference"
    end

    it do
      author = doc.at("./front/author")
      expect(described_class.person(author, doc)).to be_nil
    end
  end

  shared_examples "parse_org" do |source, name, abbrev|
    let(:ref) do
      doc = Nokogiri::XML <<~XML
        <reference anchor="RFC1234" target="https://www.rfc-editor.org/info/rfc1234">
          <front>
            <author fullname="#{source}"/>
          </front>
        </reference>
      XML
      doc.at "/reference"
    end

    it "parse organization #{source}" do
      contrib = described_class.contributors ref
      orgname = name || source
      expect(contrib[1][:entity]).to be_instance_of RelatonBib::Organization
      expect(contrib[1][:entity].abbreviation.content).to eq abbrev if abbrev
      expect(contrib[1][:entity].name[0].content).to eq orgname
    end
  end

  shared_examples "parse_person" do |fullname, inits, surname, forename|
    let(:ref) do
      doc = Nokogiri::XML <<~XML
        <reference anchor="RFC1234" target="https://www.rfc-editor.org/info/rfc1234">
          <front>
            <author fullname="#{fullname}"/>
          </front>
        </reference>
      XML
      doc.at "/reference"
    end

    it "parse person #{fullname}" do
      contrib = described_class.contributors ref
      expect(contrib[1][:entity]).to be_instance_of RelatonBib::Person
      expect(contrib[1][:entity].name.completename.content).to eq fullname
      expect(contrib[1][:entity].name.initials.content).to eq inits if inits
      expect(contrib[1][:entity].name.surname.content).to eq surname
      expect(contrib[1][:entity].name.forename[0].content).to eq forename if forename
    end
  end

  it_behaves_like "parse_org", "ISO", "International Organization for Standardization", "ISO"
  it_behaves_like "parse_org", "Network Information Center. Stanford Research Institute"
  it_behaves_like "parse_org", "Information Sciences Institute University of Southern California"
  it_behaves_like "parse_org", "International Telegraph and Telephone Consultative Committee of the International Telecommunication Union",
                  "International Telegraph and Telephone Consultative Committee of the International Telecommunication Union", "CCITT"
  it_behaves_like "parse_org", "National Bureau of Standards", "National Bureau of Standards", "NBS"
  it_behaves_like "parse_org", "International Organization for Standardization", "International Organization for Standardization", "ISO"
  it_behaves_like "parse_org", "National Research Council", "National Research Council", "NRC"
  it_behaves_like "parse_org", "Gateway Algorithms and Data Structures Task Force"
  it_behaves_like "parse_org", "National Science Foundation", "National Science Foundation", "NSF"
  it_behaves_like "parse_org", "Network Technical Advisory Group"
  it_behaves_like "parse_org", "NetBIOS Working Group in the Defense Advanced Research Projects Agency"
  it_behaves_like "parse_org", "Internet Activities Board", "Internet Activities Board", "IAB"
  it_behaves_like "parse_org", "Internet Architecture Board", "Internet Architecture Board", "IAB"
  it_behaves_like "parse_org", "End-to-End Services Task Force"
  it_behaves_like "parse_org", "Defense Advanced Research Projects Agency", "Defense Advanced Research Projects Agency", "DARPA"
  it_behaves_like "parse_org", "The North American Directory Forum"
  it_behaves_like "parse_org", "North American Directory Forum"
  it_behaves_like "parse_org", "ESCC X.500/X.400 Task Force"
  it_behaves_like "parse_org", "ESnet Site Coordinating Comittee (ESCC)", "ESnet Site Coordinating Comittee (ESCC)", "ESCC"
  it_behaves_like "parse_org", "Energy Sciences Network (ESnet)", "Energy Sciences Network (ESnet)", "ESnet"
  it_behaves_like "parse_org", "Internet Engineering Steering Group", "Internet Engineering Steering Group", "IESG"
  it_behaves_like "parse_org", "RARE WG-MSG Task Force 88"
  it_behaves_like "parse_org", "Internet Assigned Numbers Authority (IANA)", "Internet Assigned Numbers Authority (IANA)", "IANA"
  it_behaves_like "parse_org", "Federal Networking Council", "Federal Networking Council", "FNC"
  it_behaves_like "parse_org", "Audio-Video Transport Working Group"
  it_behaves_like "parse_org", "KOI8-U Working Group"
  it_behaves_like "parse_org", "The Internet Society"
  it_behaves_like "parse_org", "Sun Microsystems"
  it_behaves_like "parse_org", "ACM SIGUCCS"
  it_behaves_like "parse_org", "Bolt Beranek"
  it_behaves_like "parse_org", "EARN Staff"
  it_behaves_like "parse_org", "IAB Advisory Committee"
  it_behaves_like "parse_org", "IAB and IESG"
  it_behaves_like "parse_org", "IAB", "Internet Architecture Board", "IAB"
  it_behaves_like "parse_org", "IANA", "Internet Assigned Numbers Authority", "IANA"
  it_behaves_like "parse_org", "IESG", "Internet Engineering Steering Group", "IESG"
  it_behaves_like "parse_org", "IETF Secretariat", "IETF Secretariat", "IETF"
  it_behaves_like "parse_org", "ISOC Board of Trustees"
  it_behaves_like "parse_org", "Mitra"
  it_behaves_like "parse_org", "Newman Laboratories"
  it_behaves_like "parse_org", "Vietnamese Standardization Working Group"
  it_behaves_like "parse_org", "RFC Editor, et al."

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
  it_behaves_like "parse_person", "Julian F. Reschke", "F.", "Reschke", "Julian"
  it_behaves_like "parse_person", "Henrik Levkowetz", nil, "Levkowetz", "Henrik"
end
