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
        stream: @doc.at("./xmlns:stream")&.text,
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
      series_is_also + [RelatonBib::Series.new(title: title, number: docnum)] + seires_stream
    end

    def series_is_also
      @doc.xpath("./xmlns:is-also/xmlns:doc-id").map do |s|
        /^(?<name>\D+)(?<num>\d+)/ =~ s.text
        t = RelatonBib::TypedTitleString.new(content: name)
        RelatonBib::Series.new title: t, number: num.gsub(/^0+/, "")
      end
    end

    def seires_stream
      @doc.xpath("./xmlns:stream").map do |s|
        t = RelatonBib::TypedTitleString.new content: s.text
        RelatonBib::Series.new type: "stream", title: t
      end
    end

    #
    # Parse document identifiers
    #
    # @return [Array<RelatonBib::DocumentIdettifier>] document identifiers
    #
    def parse_docid
      ids = [
        RelatonBib::DocumentIdentifier.new(id: pub_id, type: "IETF", primary: true),
        # RelatonBib::DocumentIdentifier.new(id: anchor, type: "IETF", scope: "anchor"),
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
    # Create acnhor
    #
    # @return [String] anchor
    #
    # def anchor
    #   "RFC#{docnum}"
    # end

    #
    # Create link
    #
    # @return [Array<RelatonBib::TypedUri>]
    #
    def parse_link
      url = "https://www.rfc-editor.org/info/rfc#{docnum}"
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
    def parse_contributor # rubocop:disable Metrics/MethodLength
      contribs = @doc.xpath("./xmlns:author").map do |contrib|
        name = contrib.at("./xmlns:name").text
        entity = BibXMLParser.full_name_org name
        unless entity
          fname = BibXMLParser.full_name name, nil, nil, "en", "Latn"
          entity = RelatonBib::Person.new(name: fname)
        end
        RelatonBib::ContributionInfo.new(entity: entity, role: parse_role(contrib))
      end
      contribs << create_org_contrib("RFC Publisher", "publisher")
      contribs << create_org_contrib("RFC Series", "authorizer")
    end

    def create_org_contrib(org_name, role_type)
      org = RelatonBib::Organization.new name: org_name
      RelatonBib::ContributionInfo.new entity: org, role: [{ type: role_type }]
    end

    #
    # Parse contributors role
    #
    # @param [Nokogiri::XML::Node] contrib contributor
    #
    # @return [Array<Hash>] contributor's role
    #
    def parse_role(contrib)
      type = contrib.at("./xmlns:title")&.text&.downcase || "author"
      role = { type: type }
      [role]
    end

    #
    # Ctreat initials
    #
    # @param [String] int
    #
    # @return [Array<RelatonBib::Forename>]
    #
    def forename(int)
      return [] unless int

      int.split(/\.-?\s?|\s/).map do |i|
        RelatonBib::Forename.new initial: i, language: "en", script: "Latn"
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
        docid = RelatonBib::DocumentIdentifier.new type: "IETF", id: r.text, primary: true
        bib = IetfBibliographicItem.new(formattedref: fref, docid: [docid])
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
