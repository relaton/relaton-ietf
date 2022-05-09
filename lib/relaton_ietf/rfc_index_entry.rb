module RelatonIetf
  class RfcIndexEntry
    #
    # Document parser initalization
    #
    # @param [Nokogiri::XML::Element] doc document
    # @param [String] doc_id document id
    # @param [Array<String>] is_also included document ids
    #
    def initialize(doc, doc_id, is_also)
      @doc = doc
      @name = doc.name.split("-").first
      @shortnum = doc_id[-4..-1].sub(/^0+/, "")
      @doc_id = doc_id
      @is_also = is_also
    end

    #
    # Initialize document parser and run it
    #
    # @param [Nokogiri::XML::Element] doc document
    #
    # @return [RelatonIetf::IetfBibliographicItem, nil]
    #
    def self.parse(doc)
      doc_id = doc.at("./xmlns:doc-id")
      is_also = doc.xpath("./xmlns:is-also/xmlns:doc-id").map &:text
      return unless doc_id && is_also.any?

      new(doc, doc_id.text, is_also).parse
    end

    #
    # Parse document
    #
    # @return [RelatonIetf::IetfBibliographicItem] bib item
    #
    def parse
      IetfBibliographicItem.new(
        docnumber: docnumber,
        type: "standard",
        docid: parse_docid,
        language: ["en"],
        script: ["Latn"],
        link: parse_link,
        formattedref: formattedref,
        relation: parse_relation,
      )
    end

    #
    # Document number
    #
    # @return [Strinng] document number
    #
    def docnumber
      @doc_id
    end

    #
    # Create docidentifiers
    #
    # @return [Array<RelatonBib::DocumentIdentifier>] docidentifiers
    #
    def parse_docid
      [
        RelatonBib::DocumentIdentifier.new(type: "IETF", id: pub_id, primary: true),
        RelatonBib::DocumentIdentifier.new(type: "IETF", scope: "anchor", id: anchor),
      ]
    end

    #
    # Create pub_id
    #
    # @return [String] pub_id
    #
    def pub_id
      "#{@name.upcase} #{@shortnum}"
    end

    #
    # Create anchor
    #
    # @return [String] anchor
    #
    def anchor
      "#{@name.upcase}#{@shortnum}"
    end

    #
    # Create link
    #
    # @return [Array<RelatonBib::TypedUri>] 
    #
    def parse_link
      [RelatonBib::TypedUri.new(type: "src", content: "https://www.rfc-editor.org/info/#{@name}#{@shortnum}")]
    end

    #
    # Create formatted reference
    #
    # @return [RelatonBib::FormattedRef] 
    #
    def formattedref
      RelatonBib::FormattedRef.new(
        content: anchor, language: "en", script: "Latn",
      )
    end

    #
    # Create relations
    #
    # @return [Array<Hash>] relations
    #
    def parse_relation
      @is_also.map do |ref|
        fref = RelatonBib::FormattedRef.new content: ref
        docid = RelatonBib::DocumentIdentifier.new(type: "IETF", id: ref, primary: true)
        bib = IetfBibliographicItem.new formattedref: fref, docid: [docid]
        { type: "includes", bibitem: bib }
      end
    end
  end
end
