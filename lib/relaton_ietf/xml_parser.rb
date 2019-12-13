require "nokogiri"

module RelatonIetf
  class XMLParser < RelatonBib::XMLParser
    class << self
      def from_xml(xml)
        doc = Nokogiri::XML(xml)
        doc.remove_namespaces!
        ietfitem = doc.at("/bibitem|/bibdata")
        RelatonIetf::IetfBibliographicItem.new(item_data(ietfitem))
      end

      private

      def item_data(ietfitem)
        data = super
        ext = ietfitem.at "./ext"
        return data unless ext

        data[:doctype] = ext.at("./doctype")&.text
        data
      end
    end
  end
end
