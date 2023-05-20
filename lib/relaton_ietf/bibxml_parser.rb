require "relaton_ietf/ietf_bibliographic_item"
require "relaton_ietf/committee"

module RelatonIetf
  module BibXMLParser
    include RelatonBib::BibXMLParser
    extend BibXMLParser

    # @param attrs [Hash]
    # @return [RelatonIetf::IetfBibliographicItem]
    def bib_item(**attrs)
      unless attrs.delete(:is_relation)
        # attrs[:fetched] = Date.today.to_s
        # attrs[:place] = ["Fremont, CA"]
      end
      RelatonIetf::IetfBibliographicItem.new(**attrs)
    end

    # def docids(reference, ver)
    #   ids = super
    #   si = reference.at("./seriesInfo[@name='Internet-Draft']",
    #     "./front/seriesInfo[@name='Internet-Draft']")
    #   if si
    #     id = si[:value]
    #   end
    #   ids
    # end

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

    def person(author, reference)
      return unless author[:fullname] && author[:fullname] != "None"

      full_name_org(author[:fullname]) || super
    end

    def full_name_org(name) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
      case name
      when "ISO"
        RelatonBib::Organization.new(abbreviation: name, name: "International Organization for Standardization")
      when "IAB"
        RelatonBib::Organization.new(abbreviation: name, name: "Internet Architecture Board")
      when "IESG"
        RelatonBib::Organization.new(abbreviation: name, name: "Internet Engineering Steering Group")
      when "IANA"
        RelatonBib::Organization.new(abbreviation: name, name: "Internet Assigned Numbers Authority")
      when "International Organization for Standardization"
        RelatonBib::Organization.new(abbreviation: "ISO", name: name)
      when "Federal Networking Council", "Internet Architecture Board", "Internet Activities Board",
        "Defense Advanced Research Projects Agency", "National Science Foundation",
        "National Research Council", "National Bureau of Standards",
        "Internet Engineering Steering Group"
        abbr = name.split.map { |w| w[0] if w[0] == w[0].upcase }.join
        RelatonBib::Organization.new(abbreviation: abbr, name: name)
      when "IETF Secretariat"
        RelatonBib::Organization.new(abbreviation: "IETF", name: name)
      when "Audio-Video Transport Working Group", /North American Directory Forum/, "EARN Staff",
        "Vietnamese Standardization Working Group", "ACM SIGUCCS", "ESCC X.500/X.400 Task Force",
        "Sun Microsystems", "NetBIOS Working Group in the Defense Advanced Research Projects Agency",
        "End-to-End Services Task Force", "Network Technical Advisory Group", "Bolt Beranek",
        "Newman Laboratories", "Gateway Algorithms and Data Structures Task Force",
        "Network Information Center. Stanford Research Institute", "RFC Editor",
        "Information Sciences Institute University of Southern California", "IAB and IESG",
        "RARE WG-MSG Task Force 88", "KOI8-U Working Group", "The Internet Society",
        "IAB Advisory Committee", "ISOC Board of Trustees", "Mitra", "RFC Editor, et al."
        RelatonBib::Organization.new(name: name)
      when "Internet Assigned Numbers Authority (IANA)"
        RelatonBib::Organization.new(abbreviation: "IANA", name: "Internet Assigned Numbers Authority (IANA)")
      when "ESnet Site Coordinating Comittee (ESCC)"
        RelatonBib::Organization.new(abbreviation: "ESCC", name: "ESnet Site Coordinating Comittee (ESCC)")
      when "Energy Sciences Network (ESnet)"
        RelatonBib::Organization.new(abbreviation: "ESnet", name: "Energy Sciences Network (ESnet)")
      when "International Telegraph and Telephone Consultative Committee of the International Telecommunication Union"
        RelatonBib::Organization.new(abbreviation: "CCITT", name: name)
      end
    end

    #
    # Overrade RelatonBib::BibXMLParser#full_name method
    #
    # @param fname [String] full name
    # @param sname [String, nil] surname
    # @param fname [String, nil] first name
    # @param lang [String, nil] language
    # @param script [String, nil] script
    #
    # @return [RelatonBib::FullName]
    #
    def full_name(fname, sname, inits, lang, script = nil)
      surname, ints, name = parse_surname_initials fname, sname, inits
      initials = localized_string(ints, lang, script)
      RelatonBib::FullName.new(
        completename: localized_string(fname, lang, script),
        initials: initials, forename: forename(ints, name, lang, script),
        surname: localized_string(surname, lang, script)
      )
    end

    #
    # Create forenames with initials
    #
    # @param [String] initials initials
    # @param [String] lang language
    #
    # @return [Array<RelatonBib::Forename>] forenames
    #
    def forename(initials, name, lang = nil, script = nil)
      fnames = []
      if name
        fnames << RelatonBib::Forename.new(content: name, language: lang, script: script)
      end
      return fnames unless initials

      initials.split(/\.-?\s?|\s/).each_with_object(fnames) do |i, a|
        a << RelatonBib::Forename.new(initial: i, language: lang, script: script)
      end
    end

    #
    # Parse name, surname, and initials from full name
    #
    # @param [String] fname full name
    # @param [String, nil] sname surname
    # @param [String, nil] inits
    #
    # @return [Array<String, nil>] surname, initials, forename
    #
    def parse_surname_initials(fname, sname, inits) # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
      regex = /(?:(?<name>\w{3,})\s)?(?<inits>(?:[A-Z]{1,2}(?:\.[\s-]?|\s))+)?/
      match = fname&.match(regex)
      surname = sname || fname&.sub(regex, "")&.strip
      initials = inits || (match && match[:inits]&.strip)
      [surname, initials, (match && match[:name])]
    end
  end
end
