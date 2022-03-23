module RelatonIetf
  class RfcIndexEntry
    #
    # Document parser initalization
    #
    # @param [String] name document type name
    # @param [String] doc_id document id
    # @param [Array<String>] is_also included document ids
    #
    def initialize(name, doc_id, is_also)
      @name = name
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

      name = doc.name.split("-").first
      new(name, doc_id.text, is_also).parse
    end

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
    # Document id
    #
    # @return [Strinng] document id
    #
    def docnumber
      @doc_id
    end

    def parse_docid
      [
        RelatonBib::DocumentIdentifier.new(type: "IETF", id: pub_id, primary: true),
        RelatonBib::DocumentIdentifier.new(type: "IETF", scope: "anchor", id: anchor),
      ]
    end

    def pub_id
      "#{@name.upcase} #{@shortnum}"
    end

    def anchor
      "#{@name.upcase}#{@shortnum}"
    end

    def parse_link
      [RelatonBib::TypedUri.new(type: "src", content: "https://www.rfc-editor.org/info/#{@name}#{@shortnum}")]
    end

    def formattedref
      RelatonBib::FormattedRef.new(
        content: anchor, language: "en", script: "Latn",
      )
    end

    def parse_relation
      @is_also.each_with_object([]) do |ref, a|
        bib = IetfBibliography.get ref.sub(/^(RFC)(\d+)/, '\1 \2')
        a << { type: "includes", bibitem: bib } if bib
      end
    end
  end
end
