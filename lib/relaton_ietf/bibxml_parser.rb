module RelatonIetf
  module BibXMLParser
    include RelatonBib::BibXMLParser
    extend BibXMLParser

    FULLNAMEORG = [
      "IAB", "Internet Architecture Board", "IAB and IESG", "IESG",
      "IAB Advisory Committee", "Internet Engineering Steering Group",
      "Network Information Center. Stanford Research Institute",
      "Information Sciences Institute University of Southern California",
      "International Telegraph and Telephone Consultative Committee of the International Telecommunication Union",
      "National Bureau of Standards", "International Organization for Standardization",
      "National Research Council", "Gateway Algorithms and Data Structures Task Force",
      "National Science Foundation", "Network Technical Advisory Group",
      "NetBIOS Working Group in the Defense Advanced Research Projects Agency",
      "Internet Activities Board", "End-to-End Services Task Force",
      "Defense Advanced Research Projects Agency", "The North American Directory Forum",
      "ESCC X.500/X.400 Task Force", "ESnet Site Coordinating Comittee (ESCC)",
      "Energy Sciences Network (ESnet)", "RARE WG-MSG Task Force 88",
      "Internet Assigned Numbers Authority (IANA)", "Federal Networking Council",
      "Audio-Video Transport Working Group", "KOI8-U Working Group",
      "The Internet Society", "Sun Microsystems"
    ].freeze

    # @param attrs [Hash]
    # @return [RelatonIetf::IetfBibliographicItem]
    def bib_item(**attrs)
      unless attrs.delete(:is_relation)
        # attrs[:fetched] = Date.today.to_s
        # attrs[:place] = ["Fremont, CA"]
      end
      RelatonIetf::IetfBibliographicItem.new(**attrs)
    end

    #
    # Extract document identifier type form identifier
    #
    # @param [String] id identifier
    #
    # @return [String] type
    #
    def pubid_type(id)
      type = super
      case type
      when "BCP", "FYI", "STD", "RFC" then "RFC"
      # when "Internet-Draft" then type
      when "I-D" then "Internet-Draft"
      else "IETF"
      end
    end

    # @param [RelatonBib::WorkGroup]
    # @return [RelatonIetf::Committee]
    def committee(wgr)
      Committee.new wgr
    end

    # @param reference [Nokogiri::XML::Element]
    # @return [Array<Hash>]
    def contributors(reference)
      contribs = []
      unless reference[:anchor]&.match?(/^I-D/)
        contribs << {
          entity: new_org("Internet Engineering Task Force", "IETF"),
          role: [type: "publisher"],
        }
      end
      contribs + super
    end

    #
    # Overrade RelatonBib::BibXMLParser#full_name method
    #
    # @param author [Nokogiri::XML::Element]
    # @param reference [Nokogiri::XML::Element]
    #
    # @return [RelatonBib::FullName]
    #
    def full_name(author, reference)
      lang = language reference
      sname, inits = parse_surname_initials author
      initials = localized_string(inits, lang)
      RelatonBib::FullName.new(
        completename: localized_string(author[:fullname], lang),
        initials: initials, forename: forename(inits, lang),
        surname: localized_string(sname, lang)
      )
    end

    def parse_surname_initials(author)
      regex = /(?:[A-Z]{1,2}(?:\.[\s-]?|\s))+/
      surname = author[:surname] || author[:fullname].sub(regex, "").strip
      inits = author[:initials] || regex.match(author[:fullname])&.to_s&.strip
      [surname, inits]
    end
  end
end
