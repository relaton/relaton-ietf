# frozen_string_literal:true

require 'rfcbib/scrapper'

module RfcBib
  # RFC bibliography module
  module RfcBibliography
    class << self
      def search(text)
        Scrapper.scrape_page text
      end
    end
  end
end
