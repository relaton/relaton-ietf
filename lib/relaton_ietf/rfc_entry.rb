module RelatonIetf
  class RfcEntry
    #
    # Initalize parser
    #
    # @param [Nokogiri::XML::Element] doc document
    #
    def initialize(doc)
      @doc = doc
    end

    #
    # Initialize parser & parse document
    #
    # @param [Nokogiri::XML::Element] doc document
    #
    # @return [RelatonIetf::IetfBibliographicItem] bib item
    #
    def self.parse(doc)
      new(doc).parse
    end

    #
    # Parse document
    #
    # @return [RelatonIetf::IetfBibliographicItem] bib item
    #
    def parse # rubocop:disable Metrics/MethodLength
      IetfBibliographicItem.new(
        type: "standard",
        language: ["en"],
        script: ["Latn"],
        fetched: Date.today.to_s,
        docid: parse_docid,
        docnumber: code,
        title: parse_title,
        link: parse_link,
        date: parse_date,
        contributor: parse_contributor,
        keyword: parse_keyword,
        abstract: parse_abstract,
        relation: parse_relation,
        status: parse_status,
        series: parse_series,
        editorialgroup: parse_editorialgroup,
      )
    end

    #
    # Parse series
    #
    # @return [Array<RelatonBib::Series>] series
    #
    def parse_series
      title = RelatonBib::TypedTitleString.new(content: "RFC")
      @doc.xpath("./xmlns:is-also/xmlns:doc-id").map do |s|
        /^(?<name>\D+)(?<num>\d+)/ =~ s.text
        t = RelatonBib::TypedTitleString.new(content: name)
        RelatonBib::Series.new title: t, number: num.gsub(/^0+/, "")
      end + [RelatonBib::Series.new(title: title, number: docnum)]
    end

    #
    # Parse document identifiers
    #
    # @return [Array<RelatonBib::DocumentIdettifier>] document identifiers
    #
    def parse_docid
      ids = [
        RelatonBib::DocumentIdentifier.new(id: pub_id, type: "IETF", primary: true),
        RelatonBib::DocumentIdentifier.new(id: code, type: "IETF", scope: "anchor"),
      ]
      doi = @doc.at("./xmlns:doi").text
      ids << RelatonBib::DocumentIdentifier.new(id: doi, type: "DOI")
      ids
    end

    #
    # Parse document title
    #
    # @return [Array<RelatonBib::TypedTileString>] document title
    #
    def parse_title
      content = @doc.at("./xmlns:title").text
      [RelatonBib::TypedTitleString.new(content: content, type: "main")]
    end

    #
    # Create PubID
    #
    # @return [String] PubID
    #
    def pub_id
      "RFC #{docnum}"
    end

    #
    # Parse document number
    #
    # @return [String] document number
    #
    def docnum
      /\d+$/.match(code).to_s.sub(/^0+/, "")
    end

    #
    # Parse document code
    #
    # @return [String] document code
    #
    def code
      @doc.at("./xmlns:doc-id").text
    end

    #
    # Create link
    #
    # @return [Array<RelatonBib::TypedUri>] 
    #
    def parse_link
      num = code[-4..-1].sub(/^0+/, "")
      url = "https://www.rfc-editor.org/info/rfc#{num}"
      [RelatonBib::TypedUri.new(content: url, type: "src")]
    end

    #
    # Parse document date
    #
    # @return [Array<RelatonBib::BibliographicDate>] document date
    #
    def parse_date
      @doc.xpath("./xmlns:date").map do |date|
        month = date.at("./xmlns:month").text
        year = date.at("./xmlns:year").text
        on = "#{year}-#{Date::MONTHNAMES.index(month).to_s.rjust(2, '0')}"
        RelatonBib::BibliographicDate.new(on: on, type: "published")
      end
    end

    #
    # Parse document contributors
    #
    # @return [Array<RelatonBib::ContributionInfo>] document contributors
    #
    def parse_contributor # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity
      @doc.xpath("./xmlns:author").map do |contributor| # rubocop:disable Metrics/BlockLength
        n = contributor.at("./xmlns:name").text
        case n
        when "ISO"
          entity = RelatonBib::Organization.new(abbrev: n, name: "International Organization for Standardization")
        when "International Organization for Standardization"
          entity = RelatonBib::Organization.new(abbrev: "ISO", name: n)
        when "IAB"
          entity = RelatonBib::Organization.new(abbrev: n, name: "Internet Architecture Board")
        when "IESG"
          entity = RelatonBib::Organization.new(abbrev: n, name: "Internet Engineering Steering Group")
        when "Internet Engineering Steering Group", "Federal Networking Council", "Internet Architecture Board",
          "Internet Activities Board", "Defense Advanced Research Projects Agency", "National Science Foundation",
          "National Research Council", "National Bureau of Standards"
          abbr = n.split.map { |w| w[0] if w[0] == w[0].upcase }.join
          entity = RelatonBib::Organization.new(abbrev: abbr, name: n)
        when "IETF Secretariat"
          entity = RelatonBib::Organization.new(abbrev: "IETF", name: n)
        when "Audio-Video Transport Working Group", /North American Directory Forum/, "EARN Staff",
          "Vietnamese Standardization Working Group", "ACM SIGUCCS", "ESCC X.500/X.400 Task Force",
          "Sun Microsystems", "NetBIOS Working Group in the Defense Advanced Research Projects Agency",
          "End-to-End Services Task Force", "Network Technical Advisory Group", "Bolt Beranek",
          "Newman Laboratories", "Gateway Algorithms and Data Structures Task Force",
          "Network Information Center. Stanford Research Institute", "RFC Editor",
          "Information Sciences Institute University of Southern California"
          entity = RelatonBib::Organization.new(name: n)
        when "Internet Assigned Numbers Authority (IANA)"
          entity = RelatonBib::Organization.new(abbrev: "IANA", name: "Internet Assigned Numbers Authority")
        when "ESnet Site Coordinating Comittee (ESCC)"
          entity = RelatonBib::Organization.new(abbrev: "ESCC", name: "ESnet Site Coordinating Comittee")
        when "Energy Sciences Network (ESnet)"
          entity = RelatonBib::Organization.new(abbrev: "ESnet", name: "Energy Sciences Network")
        when "International Telegraph and Telephone Consultative Committee of the International Telecommunication Union"
          entity = RelatonBib::Organization.new(abbrev: "CCITT", name: n)
        else
          # int, snm = n.split
          /^(?:(?<int>(?:\p{Lu}+(?:-\w|\(\w\))?\.{0,2}[-\s]?)+)\s)?(?<snm>[[:alnum:]\s'-.]+)$/ =~ n
          surname = RelatonBib::LocalizedString.new(snm, "en", "Latn")
          name = RelatonBib::LocalizedString.new(n, "en", "Latn")
          fname = RelatonBib::FullName.new(completename: name, initial: initials(int), surname: surname)
          entity = RelatonBib::Person.new(name: fname)
        end
        RelatonBib::ContributionInfo.new(entity: entity, role: [{ type: "author" }])
      end
    end

    #
    # Ctreat initials
    #
    # @param [String] int
    #
    # @return [Array<RelatonBib::LocalizedString>]
    #
    def initials(int)
      return [] unless int

      int.split(/\.-?\s?|\s/).map { |i| RelatonBib::LocalizedString.new i, "en", "Latn" }
    end

    #
    # Parse document keywords
    #
    # @return [Array<String>] document keywords
    #
    def parse_keyword
      @doc.xpath("./xmlns:keywords/xmlns:kw").map &:text
    end

    #
    # Parse document abstract
    #
    # @return [Array<RelatonBib::FormattedString>] document abstract
    #
    def parse_abstract
      @doc.xpath("./xmlns:abstract").map do |c|
        content = c.xpath("./xmlns:p").map do |p|
          "<#{p.name}>#{p.text.strip}</#{p.name}>"
        end.join
        RelatonBib::FormattedString.new(content: content, language: "en",
                                        script: "Latn", format: "text/html")
      end
    end

    #
    # Parse document relations
    #
    # @return [Arra<RelatonBib::DocumentRelation>] document relations
    #
    def parse_relation
      types = { "updates" => "updates", "obsoleted-by" => "obsoletedBy"}
      @doc.xpath("./xmlns:updates/xmlns:doc-id|./xmlns:obsoleted-by/xmlns:doc-id").map do |r|
        fref = RelatonBib::FormattedRef.new(content: r.text)
        bib = IetfBibliographicItem.new(formattedref: fref)
        RelatonBib::DocumentRelation.new(type: types[r.parent.name], bibitem: bib)
      end
    end

    #
    # Parse document status
    #
    # @return [RelatonBib::DocuemntStatus] document status
    #
    def parse_status
      stage = @doc.at("./xmlns:current-status").text
      RelatonBib::DocumentStatus.new(stage: stage)
    end

    #
    # Parse document editorial group
    #
    # @return [RelatonBib::EditorialGroup] document editorial group
    #
    def parse_editorialgroup
      tc = @doc.xpath("./xmlns:wg_acronym").each_with_object([]) do |wg, arr|
        next if wg.text == "NON WORKING GROUP"

        wg = RelatonBib::WorkGroup.new(name: wg.text)
        arr << RelatonBib::TechnicalCommittee.new(wg)
      end
      RelatonBib::EditorialGroup.new(tc) if tc.any?
    end
  end
end
