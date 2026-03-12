module Relaton
  module Ietf
    module BibXMLParser # rubocop:disable Metrics/ModuleLength
      # Workaround for rfcxml v0.2.1 circular dependency:
      # Sup inherits Sub before Sub finishes declaring attributes,
      # leaving Sup.attributes empty. Copy them over.
      if defined?(Rfcxml::V3::Sup) && Rfcxml::V3::Sup.attributes.empty?
        Rfcxml::V3::Sub.attributes.each do |name, attr|
          Rfcxml::V3::Sup.attributes[name] = attr
        end
      end

      extend self

      def parse(xml)
        reference = Rfcxml::V3::Reference.from_xml(xml)
        FromRfcxml.new(reference).transform
      end

      def parse_rfc(xml)
        rfc = Rfcxml::V3::Rfc.from_xml(xml)
        FromRfc.new(rfc).transform
      end

      def pubid_type(id)
        pref = id.match(/^(\S+)/)[1]
        case pref
        when "BCP", "FYI", "STD", "RFC" then "RFC"
        when "I-D" then "Internet-Draft"
        else "IETF"
        end
      end

      def full_name_org(name) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity
        case name
        when "ISO"
          build_org(name, "International Organization for Standardization")
        when "IAB"
          build_org(name, "Internet Architecture Board")
        when "IESG"
          build_org(name, "Internet Engineering Steering Group")
        when "IANA"
          build_org(name, "Internet Assigned Numbers Authority")
        when "International Organization for Standardization"
          build_org("ISO", name)
        when "Federal Networking Council", "Internet Architecture Board", "Internet Activities Board",
          "Defense Advanced Research Projects Agency", "National Science Foundation",
          "National Research Council", "National Bureau of Standards",
          "Internet Engineering Steering Group"
          abbr = name.split.map { |w| w[0] if w[0] == w[0].upcase }.join
          build_org(abbr, name)
        when "IETF Secretariat"
          build_org("IETF", name)
        when "Audio-Video Transport Working Group", /North American Directory Forum/, "EARN Staff",
          "Vietnamese Standardization Working Group", "ACM SIGUCCS", "ESCC X.500/X.400 Task Force",
          "Sun Microsystems", "NetBIOS Working Group in the Defense Advanced Research Projects Agency",
          "End-to-End Services Task Force", "Network Technical Advisory Group", "Bolt Beranek",
          "Newman Laboratories", "Gateway Algorithms and Data Structures Task Force",
          "Network Information Center. Stanford Research Institute", "RFC Editor",
          "Information Sciences Institute University of Southern California", "IAB and IESG",
          "RARE WG-MSG Task Force 88", "KOI8-U Working Group", "The Internet Society",
          "IAB Advisory Committee", "ISOC Board of Trustees", "Mitra", "RFC Editor, et al."
          build_org(nil, name)
        when "Internet Assigned Numbers Authority (IANA)"
          build_org("IANA", "Internet Assigned Numbers Authority (IANA)")
        when "ESnet Site Coordinating Comittee (ESCC)"
          build_org("ESCC", "ESnet Site Coordinating Comittee (ESCC)")
        when "Energy Sciences Network (ESnet)"
          build_org("ESnet", "Energy Sciences Network (ESnet)")
        when "International Telegraph and Telephone Consultative Committee of the International Telecommunication Union"
          build_org("CCITT", name)
        end
      end

      def build_org(abbr, name)
        args = { name: [Bib::TypedLocalizedString.new(content: name, language: "en")] }
        args[:abbreviation] = Bib::LocalizedString.new(content: abbr, language: "en") if abbr && !abbr.empty?
        Bib::Organization.new(**args)
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

      class FromRfcxml < Bib::Converter::BibXml::FromRfcxml # rubocop:disable Metrics/ClassLength
        private

        def pubid_type(id)
          BibXMLParser.pubid_type(id)
        end

        def contributor # rubocop:disable Metrics/MethodLength
          contribs = []
          unless @reference.anchor&.match?(/^I-D/)
            org = BibXMLParser.build_org("IETF", "Internet Engineering Task Force")
            contribs << Bib::Contributor.new(
              organization: org,
              role: [Bib::Contributor::Role.new(type: "publisher")],
            )
          end
          contribs + super
        end

        def person(author)
          return unless author.fullname && author.fullname != "None"
          return if BibXMLParser.full_name_org(author.fullname)

          super
        end

        def organization(author)
          if author.fullname
            org = BibXMLParser.full_name_org(author.fullname)
            return org if org
          end
          super
        end

        def person_name(author) # rubocop:disable Metrics/MethodLength
          fname = author.fullname
          surname, inits, forename = BibXMLParser.parse_surname_initials(
            fname, author.surname, author.initials
          )
          fnames = []
          if forename
            fnames << Bib::FullNameType::Forename.new(
              content: forename, language: "en", script: "Latn",
            )
          end
          if inits
            inits.split(/\.-?\s?|\s/).each do |i|
              fnames << Bib::FullNameType::Forename.new(
                initial: i, language: "en", script: "Latn",
              )
            end
          end
          Bib::FullName.new(
            completename: Bib::LocalizedString.new(content: fname, language: "en"),
            formatted_initials: inits ? Bib::LocalizedString.new(content: inits, language: "en") : nil,
            surname: Bib::LocalizedString.new(content: surname, language: "en"),
            forename: fnames,
          )
        end
      end

      class FromRfc < FromRfcxml # rubocop:disable Metrics/ClassLength
        def transform # rubocop:disable Metrics/MethodLength
          namespace::ItemData.new(
            docnumber: doc_name&.sub(/^\w+\./, ""),
            type: "standard",
            docidentifier: docidentifiers,
            status: status,
            language: ["en"],
            script: ["Latn"],
            source: source,
            title: title,
            abstract: abstract,
            contributor: contributor + workgroup_contributors,
            date: date,
            series: series,
            keyword: keyword,
            ext: ext,
          )
        end

        private

        def doc_name = @reference.doc_name

        def docidentifiers
          ids = []
          if doc_name
            ids << Bib::Docidentifier.new(type: "Internet-Draft", content: doc_name, primary: true)
            ids << Bib::Docidentifier.new(type: "IETF", content: doc_name, scope: "docName")
          end
          ids + docid_from_series_info
        end

        def source = []

        def contributor # rubocop:disable Metrics/MethodLength
          contribs = []
          org = BibXMLParser.build_org("IETF", "Internet Engineering Task Force")
          contribs << Bib::Contributor.new(
            organization: org,
            role: [Bib::Contributor::Role.new(type: "publisher")],
          )
          contribs + Bib::Converter::BibXml::FromRfcxml.instance_method(:contributor).bind_call(self)
        end

        def doctype
          namespace::Doctype.new(content: "rfc")
        end

        def series
          front_si = @reference.front.series_info || []
          front_si.filter_map do |si|
            next if si.name == "DOI" || si.stream || si.status

            t = Bib::Title.new(content: si.name, language: "en", script: "Latn")
            Bib::Series.new(title: [t], number: si.value, type: "main")
          end
        end

        def status
          si = @reference.front.series_info&.find(&:status)
          return unless si

          stage = Bib::Status::Stage.new(content: si.status)
          Bib::Status.new(stage: stage)
        end

        def versioned_internet_draft_id
          internet_draft_series_info(@reference.front)
        end

        def docid_from_series_info
          front_si = @reference.front.series_info || []
          front_si.each_with_object([]) do |s, acc|
            next unless s.name.casecmp("doi").zero?

            acc << Bib::Docidentifier.new(type: "DOI", content: s.value)
          end
        end
      end
    end
  end
end
