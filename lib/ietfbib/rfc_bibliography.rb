# frozen_string_literal:true

require 'ietfbib/scrapper'

module IETFBib
  # RFC bibliography module
  module RfcBibliography
    class << self
      # @param code [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @return [IsoBibItem::BibliographicItem]
      def search(text)
        Scrapper.scrape_page text
      end

      # @param code [String] the ISO standard Code to look up (e..g "ISO 9000")
      # @param year [String] the year the standard was published (optional)
      # @param opts [Hash] options; restricted to :all_parts if all-parts reference is required
      # @return [IsoBibItem::BibliographicItem] Relaton of reference
      def get(code, _year, _opts)
        search code
      end
    end
  end
end
