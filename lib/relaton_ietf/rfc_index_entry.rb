module RelatonIetf
  class RfcIndexEntry
    #
    # Document parser initalization
    #
    # @param [String] doc_id document id
    # @param [Array<String>] is_also also document ids
    #
    def initialize(name, doc_id, is_also)
      @name = name
      @shortnum = doc_id[-4..-1].sub(/^0+/, "")
      @doc_id = doc_id
      @is_also = is_also
    end

    #
    # Check if document has icluddes
    #
    # @return [Boolean] true if has includes
    #
    def has_also?
      @is_also.any?
    end

    #
    # File name for document
    #
    # @param [String] dir output directory
    #
    # @return [String] file name
    #
    def filename(dir = "")
      File.join dir, "#{@doc_id}.xml"
    end

    #
    # Initialize document parser and run it
    #
    # @param [Nokogiri::XML::Element] doc document
    #
    # @return [RelatonIetf:RfcIndexEntry, nil]
    #
    def self.parse(doc)
      doc_id = doc.at("./xmlns:doc-id")
      return unless doc_id

      name = doc.name.split("-").first
      is_also = doc.xpath("./xmlns:is-also/xmlns:doc-id").map &:text
      new(name, doc_id.text, is_also)
    end

    #
    # Render document as XML
    #
    # @return [String] XML
    #
    def to_xml # rubocop:disable Metrics/MethodLength
      Nokogiri::XML::Builder.new do |xml|
        anchor = "#{@name.upcase}#{@shortnum}"
        url = "https://www.rfc-editor.org/info/#{@name}#{@shortnum}"
        xml.referencegroup("xmlns:xi" => "http://www.w3.org/2001/XInclude",
                           anchor: anchor, target: url) do
          @is_also.each do |did|
            num = did[-4..-1]
            xml["xi"].send("include", href: "https://www.rfc-editor.org/refs/bibxml/reference.RFC.#{num}.xml")
          end
        end
      end.to_xml
    end
  end
end
