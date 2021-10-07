# frozen_string_literal: true

require "net/http"
require "relaton_bib"
require "relaton_ietf/ietf_bibliographic_item"

module RelatonIetf
  # rubocop:disable Metrics/ModuleLength

  # Scrapper module
  module Scrapper
    GH_URL = "https://raw.githubusercontent.com/relaton/relaton-data-ietf/master/data/reference."
    # BCP_URI_PATTERN = "https://www.rfc-editor.org/info/CODE"

    class << self
      # @param text [String]
      # @param is_relation [TrueClass, FalseClass]
      # @return [RelatonIetf::IetfBibliographicItem]
      def scrape_page(text, is_relation: false)
        # Remove initial "IETF " string if specified
        ref = text.gsub(/^IETF /, "")
        /^(?:RFC|BCP|FYI|STD)\s(?<num>\d+)/ =~ ref
        ref.sub! /(?<=^(?:RFC|BCP|FYI|STD)\s)(\d+)/, num.rjust(4, "0") if num
        rfc_item ref, is_relation
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError, SocketError
        raise RelatonBib::RequestError, "No document found for #{ref} reference"
      end

      # @param reference [Nokogiri::XML::Element, nil]
      # @param is_relation [TrueClass, FalseClass]
      # @param url [String, NilClass]
      # @param ver [String, NilClass] Internet Draft version
      # @return [RelatonIetf::IetfBibliographicItem]
      def fetch_rfc(reference, is_relation: false, url: nil, ver: nil) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        return unless reference

        ietf_item(
          is_relation: is_relation,
          id: reference[:anchor],
          type: "standard",
          docid: docids(reference, ver),
          status: status(reference),
          language: [language(reference)],
          link: link(reference, url, ver),
          title: titles(reference),
          formattedref: formattedref(reference),
          abstract: abstracts(reference),
          contributor: contributors(reference),
          relation: relations(reference),
          date: dates(reference),
          series: series(reference),
          place: ["Fremont, CA"],
          keyword: reference.xpath("front/keyword").map(&:text),
          doctype: doctype(reference[:anchor]),
        )
      end

      private

      # @param anchor [String]
      # @return [String]
      def doctype(anchor)
        anchor&.include?("I-D") ? "internet-draft" : "rfc"
      end

      # @param reference [Nokogiri::XML::Element]
      # @param url [String]
      # @param ver [String, NilClass] Internet Draft version
      # @return [Array<Hash>]
      def link(reference, url, ver)
        l = []
        l << { type: "xml", content: url } if url
        l << { type: "src", content: reference[:target] } if reference[:target]
        if /^I-D/.match? reference[:anchor]
          reference.xpath("format").each do |f|
            c = ver ? f[:target].sub(/(?<=-)\d{2}(?=\.)/, ver) : f[:target]
            l << { type: f[:type], content: c }
          end
        end
        l
      end

      # @param attrs [Hash]
      # @return [RelatonIetf::IetfBibliographicItem]
      def ietf_item(**attrs)
        attrs[:fetched] = Date.today.to_s unless attrs.delete(:is_relation)
        attrs[:script] = ["Latn"]
        RelatonIetf::IetfBibliographicItem.new **attrs
      end

      # @param ref [String]
      # @param is_relation [Boolen, nil]
      # @return [RelatonIetf::IetfBibliographicItem]
      def rfc_item(ref, is_relation)
        /(?<=-)(?<ver>\d{2})$/ =~ ref
        if /^I-D/.match? ref
          ref.sub! /-\d{2}/, "" if ver
          ref.sub! /(?<=I-D\.)draft-/, ""
        end

        uri = "#{GH_URL}#{ref.sub(/\s|\u00a0/, '.')}.xml"
        doc = Nokogiri::XML get_page(uri)
        r = doc.at("/referencegroup", "/reference")
        fetch_rfc r, is_relation: is_relation, url: uri, ver: ver
      end

      # @param reference [Nokogiri::XML::Element]
      # @return [Hash]
      def relations(reference)
        reference.xpath("reference").map do |ref|
          { type: "includes", bibitem: fetch_rfc(ref, is_relation: true) }
        end
      end

      # @param uri [String]
      # @return [String] HTTP response body
      def get_page(uri)
        res = Net::HTTP.get_response(URI(uri))
        return unless res.code == "200"

        #   raise RelatonBib::RequestError, "No document found at #{uri}"
        # end

        res.body
      end

      # @param reference [Nokogiri::XML::Element]
      # @return [String]
      def language(reference)
        reference[:lang] || "en"
      end

      # @param reference [Nokogiri::XML::Element]
      # @return [Array<Hash>]
      def titles(reference)
        reference.xpath("./front/title").map do |title|
          { content: title.text, language: language(reference), script: "Latn" }
        end
      end

      # @param reference [Nokogiri::XML::Element]
      # @return [RelatonBib::FormattedRef, nil]
      def formattedref(reference)
        return if reference.at "./fornt/title"

        cont = (reference[:anchor] || reference[:docName] || reference[:number])
        if cont
          RelatonBib::FormattedRef.new(
            content: cont, language: language(reference), script: "Latn",
          )
        end
      end

      # @param reference [Nokogiri::XML::Element]
      # @return [Array<RelatonBib::FormattedString>]
      def abstracts(ref)
        ref.xpath("./front/abstract").map do |a|
          RelatonBib::FormattedString.new(
            content: a.text.gsub(/\\n\\t{2,4}/, " ").strip,
            language: language(ref), script: "Latn"
          )
        end
      end

      # @param reference [Nokogiri::XML::Element]
      # @return [Array<Hash>]
      def contributors(reference)
        persons(reference) + organizations(reference)
      end

      # @param reference [Nokogiri::XML::Element]
      # @return [Array<Hash{Symbol=>RelatonBib::Person,Symbol=>Array<String>}>]
      def persons(reference)
        reference.xpath("./front/author[@surname]|./front/author[@fullname]")
          .map do |author|
          entity = RelatonBib::Person.new(
            name: full_name(author, reference),
            affiliation: [affiliation(author)],
            contact: contacts(author.at("./address")),
          )
          { entity: entity, role: [contributor_role(author)] }
        end
      end

      # @param reference [Nokogiri::XML::Element]
      # @return [Array<Hash{Symbol=>RelatonBib::Organization,
      #   Symbol=>Array<String>}>]
      def organizations(reference)
        publisher = { entity: new_org, role: [type: "publisher"] }
        orgs = reference.xpath("./seriesinfo").reduce([publisher]) do |mem, si|
          next mem unless si[:stream]

          mem << { entity: new_org(si[:stream], nil), role: [type: "author"] }
        end
        orgs + reference.xpath(
          "front/author[not(@surname)][not(@fullname)]/organization",
        ).map do |org|
          { entity: new_org(org.text, nil), role: [type: "author"] }
        end
      end

      # @param author [Nokogiri::XML::Element]
      # @param ref [Nokogiri::XML::Element]
      # @return [RelatonBib::FullName]
      def full_name(author, ref)
        lang = language ref
        RelatonBib::FullName.new(
          completename: localized_string(author[:fullname], lang),
          initial: [localized_string(author[:initials], lang)].compact,
          surname: localized_string(author[:surname], lang),
        )
      end

      # @param content [String]
      # @param lang [String]
      # @return [RelatonBib::LocalizedString]
      def localized_string(content, lang)
        return unless content

        RelatonBib::LocalizedString.new(content, lang)
      end

      # @param postal [Nokogiri::XML::Element]
      # @return [Array<RelatonBib::Address, RelatonBib::Phone>]
      def contacts(addr)
        contacts = []
        return contacts unless addr

        postal = addr.at("./postal")
        contacts << address(postal) if postal
        add_contact(contacts, "phone", addr.at("./phone"))
        add_contact(contacts, "email", addr.at("./email"))
        add_contact(contacts, "uri", addr.at("./uri"))
        contacts
      end

      # @param postal [Nokogiri::XML::Element]
      # @rerurn [RelatonBib::Address]
      def address(postal) # rubocop:disable Metrics/CyclomaticComplexity
        RelatonBib::Address.new(
          street: [(postal.at("./postalLine") || postal.at("./street"))&.text],
          city: postal.at("./city")&.text,
          postcode: postal.at("./code")&.text,
          country: postal.at("./country")&.text,
          state: postal.at("./region")&.text,
        )
      end

      # @param type [String] allowed "phone", "email" or "uri"
      # @param value [String]
      def add_contact(contacts, type, value)
        return unless value

        contacts << RelatonBib::Contact.new(type: type, value: value.text)
      end

      # @param author [Nokogiri::XML::Element]
      # @return [RelatonBib::Affiliation]
      def affiliation(author)
        organization = author.at("./organization")
        org = if organization.nil? || organization&.text&.empty?
                new_org
              else
                new_org organization.text, organization[:abbrev]
              end
        RelatonBib::Affiliation.new organization: org
      end

      # @param name [String]
      # @param abbr [String]
      # @return [RelatonBib::Organization]
      def new_org(name = "Internet Engineering Task Force", abbr = "IETF")
        RelatonBib::Organization.new name: name, abbreviation: abbr
      end

      # @param author [Nokogiri::XML::Document]
      # @return [Hash]
      def contributor_role(author)
        { type: author[:role] || "author" }
      end

      def month(mon)
        return 1 if !mon || mon.empty?
        return mon if /^\d+$/.match? mon

        Date::MONTHNAMES.index(mon)
      end

      #
      # Extract date from reference.
      #
      # @param reference [Nokogiri::XML::Element]
      # @return [Array<RelatonBib::BibliographicDate>] published data.
      #
      def dates(reference)
        return unless (date = reference.at "./front/date")

        d = [date[:year], month(date[:month]),
             (date[:day] || 1)].compact.join "-"
        date = Time.parse(d).strftime "%Y-%m-%d"
        [RelatonBib::BibliographicDate.new(type: "published", on: date)]
      end

      #
      # Extract document identifiers from reference
      #
      # @param reference [Nokogiri::XML::Element]
      # @param ver [String, NilClass] Internet Draft version
      #
      # @return [Array<RelatonBib::DocumentIdentifier>]
      #
      def docids(reference, ver) # rubocop:disable Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/AbcSize
        id = (reference[:anchor] || reference[:docName] || reference[:number])
        ret = []
        if id
          ret << RelatonBib::DocumentIdentifier.new(
            type: "IETF", id: id.sub(/^(RFC)/, "\\1 "),
          )
        end
        if (id = reference[:anchor])
          ret << RelatonBib::DocumentIdentifier.new(type: "rfc-anchor", id: id)
        end
        ret + reference.xpath("./seriesInfo").map do |si|
          next unless ["DOI", "Internet-Draft"].include? si[:name]

          id = si[:value]
          id.sub! /(?<=-)\d{2}$/, ver if ver && si[:name] == "Internet-Draft"
          RelatonBib::DocumentIdentifier.new(id: id, type: si[:name])
        end.compact
      end

      #
      # Extract series form reference
      # @param reference [Nokogiri::XML::Element]
      #
      # @return [Array<RelatonBib::Series>]
      #
      def series(reference)
        reference.xpath("./seriesInfo").map do |si|
          next if si[:name] == "DOI" || si[:stream] || si[:status]

          RelatonBib::Series.new(
            title: RelatonBib::TypedTitleString.new(
              content: si[:name], language: language(reference), script: "Latn",
            ),
            number: si[:value],
            type: "main",
          )
        end.compact
      end

      #
      # extract status
      # @param reference [Nokogiri::XML::Element]
      #
      # @return [RelatonBib::DocumentStatus]
      #
      def status(reference)
        st = reference.at("./seriesinfo[@status]")
        return unless st

        RelatonBib::DocumentStatus.new(stage: st[:status])
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
