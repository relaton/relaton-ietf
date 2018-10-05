require 'nokogiri'

module IETFBib
  class XMLParser < IsoBibItem::XMLParser
    class << self
      def from_xml(xml)
        doc = Nokogiri::XML(xml)
        IsoBibItem::BibliographicItem.new( 
          id:           fetch_id(doc),
          docid:        fetch_docid(doc),
          edition:      doc.at('/bibitem/edition')&.text,
          language:     doc.xpath('/bibitem/language').map(&:text),
          script:       doc.xpath('/bibitem/script').map(&:text),
          titles:       fetch_titles(doc),
          type:         doc.at('bibitem')&.attr(:type),
          ics:          fetch_ics(doc),
          dates:        fetch_dates(doc),
          contributors: fetch_contributors(doc),
          workgroup:    fetch_workgroup(doc),
          abstract:     fetch_abstract(doc),
          copyright:    fetch_copyright(doc),
          link:         fetch_link(doc),
          relations:    fetch_relations(doc),
          series:       fetch_series(doc)
        )
      end

      private

      def fetch_id(doc)
        doc.at('/bibitem')[:id]
      end

      def fetch_titles(doc)
        doc.xpath('/bibitem/title').map do |t|
          { content: t.text, language: t[:language], script: t[:script] }
        end
      end

      def fetch_series(doc)
        doc.xpath('/bibitem/series').map do |s|
          t = s.at('./title')
          title = IsoBibItem::FormattedString.new(
            content: t.text,
            language: t[:language],
            type: t[:format],
            script: t[:script]
          )
          abbr = s.at('./abbreviation')
          abbr = IsoBibItem::LocalizedString.new(abbr.text) if abbr
          IsoBibItem::Series.new(
            title: title,
            type: s[:type],
            place: s.at('./place')&.text,
            organization: s.at('./organization')&.text,
            abbreviation: abbr,
            from: s.at('./from')&.text,
            to: s.at('./to')&.text,
            number: s.at('./number')&.text,
            part_number: s.at('./part_numper')&.text
          )
        end
      end
    end
  end
end
