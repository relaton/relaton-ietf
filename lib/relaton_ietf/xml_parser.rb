require "nokogiri"

module RelatonIetf
  class XMLParser < RelatonBib::XMLParser
    class << self
      private

      def item_data(doc)
        data = super
        data[:stream] = doc.at("ext/stream")&.text
        data
      end

      # override RelatonBib::BibliographicItem.bib_item method
      # @param item_hash [Hash]
      # @return [RelatonIetf::IetfBibliographicItem]
      def bib_item(item_hash)
        IetfBibliographicItem.new(**item_hash)
      end

      # @param ext [Nokogiri::XML::Element]
      # @return [RelatonBib::EditorialGroup, nil]
      def fetch_editorialgroup(ext)
        return unless ext && (eg = ext.at "editorialgroup")

        eg = eg.xpath("committee").map do |tc|
          wg = RelatonBib::WorkGroup.new(
            name: tc.text, number: tc[:number]&.to_i, type: tc[:type],
            identifier: tc[:identifier], prefix: tc[:prefix]
          )
          Committee.new wg
        end
        RelatonBib::EditorialGroup.new eg if eg.any?
      end

      def create_doctype(type)
        DocumentType.new type: type.text, abbreviation: type[:abbreviation]
      end
    end
  end
end
