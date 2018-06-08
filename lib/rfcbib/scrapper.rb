# frozen_string_literal: true

require 'open-uri'
require 'nokogiri'

module RfcBib
  # Scrapper module
  module Scrapper
    class << self
      def scrape_page(text)
        html = OpenURI.open_uri "https://www.rfc-editor.org/info/#{text}"
        doc = Nokogiri::HTML html
      end
    end
  end
end
