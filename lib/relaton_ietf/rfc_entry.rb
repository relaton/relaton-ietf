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
        editorialgroup: parse_editorialgroup,
      )
    end

    #
    # Parse document identifiers
    #
    # @return [Array<RelatonBib::DocumentIdettifier>] document identifiers
    #
    def parse_docid
      ids = [RelatonBib::DocumentIdentifier.new(id: pub_id, type: "IETF")]
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
      "IETF #{code.sub(/^(RFC)(\d+)/, '\1 \2')}"
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
    def parse_contributor
      @doc.xpath("./xmlns:author").map do |contributor|
        n = contributor.at("./xmlns:name").text
        name = RelatonBib::LocalizedString.new( n,  "en",  "Latn")
        fname = RelatonBib::FullName.new(completename: name)
        person = RelatonBib::Person.new(name: fname)
        RelatonBib::ContributionInfo.new(entity: person, role: [{ type: "author" }])
      end
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
        RelatonBib::FormattedString.new(content: c.text, language: "en",
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
      tc = @doc.xpath("./xmlns:wg_acronym").map do |wg|
        wg = RelatonBib::WorkGroup.new(name: wg.text)
        RelatonBib::TechnicalCommittee.new(wg)
      end
      RelatonBib::EditorialGroup.new(tc)
    end
  end
end
