module Relaton
  module Provider
    class Ietf
      class << self
        # @param xml [String]
        # @return [RelatonIetf::IetfBibliographicItem]
        def from_rfcxml(xml)
          doc = Nokogiri::XML xml
          reference = doc.at "/rfc"
          RelatonIetf::BibXMLParser.fetch_rfc reference
        end
      end
    end
  end
end
