require "nokogiri"

module RelatonIetf
  class XMLParser < RelatonBib::XMLParser
    class << self
      private

      # override RelatonBib::BibliographicItem.bib_item method
      # @param item_hash [Hash]
      # @return [RelatonIetf::IetfBibliographicItem]
      def bib_item(item_hash)
        IetfBibliographicItem.new(**item_hash)
      end
    end
  end
end
