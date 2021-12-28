module RelatonIetf
  module BibXMLParser
    include RelatonBib::BibXMLParser
    extend BibXMLParser

    FLAVOR = "IETF".freeze

    # @param attrs [Hash]
    # @return [RelatonIetf::IetfBibliographicItem]
    def bib_item(**attrs)
      unless attrs.delete(:is_relation)
        attrs[:fetched] = Date.today.to_s
        attrs[:place] = ["Fremont, CA"]
      end
      RelatonIetf::IetfBibliographicItem.new(**attrs)
    end

    # @param [RelatonBib::WorkGroup]
    # @return [RelatonIetf::Committee]
    def committee(wgr)
      Committee.new wgr
    end

    # @param reference [Nokogiri::XML::Element]
    # @return [Array<Hash>]
    def contributors(reference)
      [{ entity: new_org("Internet Engineering Task Force", "IETF"), role: [type: "publisher"] }] + super
      # persons(reference) + organizations(reference)
    end
  end
end
