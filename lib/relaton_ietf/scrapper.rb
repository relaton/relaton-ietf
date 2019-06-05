# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "relaton_bib"

module RelatonIetf
  # rubocop:disable Metrics/ModuleLength

  # Scrapper module
  module Scrapper
    RFC_URI_PATTERN = "https://xml2rfc.tools.ietf.org/public/rfc/bibxml/reference.CODE"
    ID_URI_PATTERN = "https://xml2rfc.tools.ietf.org/public/rfc/bibxml-ids/reference.CODE"

    class << self
      # @param text [String]
      # @return [RelatonIetf::IetfBibliographicItem]
      def scrape_page(text)
        # Remove initial "IETF " string if specified
        ref = text.
          gsub(/^IETF /, "").
          sub(" ", ".") + ".xml"

        case ref
        when /^RFC/
          uri = RFC_URI_PATTERN.dup
          doctype = "rfc"
        when /^I-D/
          uri = ID_URI_PATTERN.dup
          doctype = "internet-draft"
        else
          warn "#{ref}: not recognised for RFC"
          return
        end

        uri = uri.gsub("CODE", ref)
        begin
          res = Net::HTTP.get_response(URI(uri))
          if res.code != "200"
            warn "No document found at #{uri}"
            return
          end
          doc = Nokogiri::HTML Net::HTTP.get(URI(uri))
          reference = doc.at("//reference")
          return unless reference

          bib_item reference, doctype
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
               Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError
          warn "No document found at #{uri}"
        end
      end

      private

      # rubocop:disable Metrics/MethodLength

      # @return [RelatonIetf::IetfBibliographicItem]
      def bib_item(reference, doctype)
        RelatonIetf::IetfBibliographicItem.new(
          fetched: Date.today.to_s,
          id: reference[:anchor],
          docid: docids(reference),
          status: status(reference),
          language: [language(reference)],
          script: ["Latn"],
          link: [{ type: "src", content: reference[:target] }],
          titles: titles(reference),
          contributors: contributors(reference),
          dates: dates(reference),
          series: series(reference),
          doctype: doctype,
        )
      end
      # rubocop:enable Metrics/MethodLength

      # @return [String]
      def language(reference)
        reference[:lang] || "en"
      end

      # @return [Array<Hash>]
      def titles(reference)
        title = reference.at("./front/title")
        [{ content: title.text, language: language(reference), script: "Latn" }]
      end

      # @return [Array<Hash>]
      def contributors(reference)
        persons(reference) + organizations(reference)
      end

      # @return [Array<Hash{Symbol=>RelatonBib::Person,Symbol=>Array<String>}>]
      def persons(reference)
        reference.xpath("./front/author").map do |author|
          entity = RelatonBib::Person.new(
            name: full_name(author, reference),
            affiliation: [affiliation(author)],
            contacts: contacts(author.at("./address")),
          )
          { entity: entity, roles: [contributor_role(author)] }
        end
      end

      # @return [Array<Hash{Symbol=>RelatonBib::Organization,Symbol=>Array<String>}>]
      def organizations(reference)
        reference.xpath("./seriesinfo").map do |si|
          next unless si[:stream]

          entity = RelatonBib::Organization.new name: si[:stream]
          { entity: entity, roles: ["author"] }
        end.compact
      end

      # @param author [Nokogiri::XML::Document]
      # @param ref [Nokogiri::XML::Document]
      # @return [RelatonBib::FullName]
      def full_name(author, ref)
        RelatonBib::FullName.new(
          completename: localized_string(author[:fullname], ref),
          initials: [localized_string(author[:initials], ref)],
          surname: [localized_string(author[:surname], ref)],
        )
      end

      # @param content [String]
      # @return [RelatonBib::LocalizedString]
      def localized_string(content, ref)
        RelatonBib::LocalizedString.new(content, language(ref))
      end

      # @param postal [Nokogiri::XML::Document]
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

      # @param postal [Nokogiri::XML::Document]
      # @rerurn [RelatonBib::Address]
      def address(postal)
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

      # @param author [Nokogiri::XML::Document]
      # @return [RelatonBib::Affilation]
      def affiliation(author)
        organization = author.at("./organization")
        RelatonBib::Affilation.new RelatonBib::Organization.new(
          name: organization.text.empty? ? "IETF" : organization.text,
          abbreviation: organization[:abbrev] || "IETF",
        )
      end

      # @param author [Nokogiri::XML::Document]
      # @return [String]
      def contributor_role(author)
        author[:role] || "author"
      end

      def month(mon)
        return mon if /^\d+$/ =~ mon

        Date::MONTHNAMES.index(mon)
      end

      #
      # Extract date from reference.
      #
      # @return [Array<RelatonBib::BibliographicDate>] published data.
      #
      def dates(reference)
        return unless (date = reference.at "./front/date")

        d = [date[:year], month(date[:month]),
             (date[:day] || "01")].compact.join "-"
        date = Time.parse(d).strftime "%Y-%m-%d"
        [RelatonBib::BibliographicDate.new(type: "published", on: date)]
      end

      #
      # Extract document identifiers from reference
      #
      # @return [Array<RelatonBib::DocumentIdentifier>]
      #
      def docids(reference)
        id = reference[:anchor].sub(/^(RFC)/, "\\1 ")
        ret = []
        ret << RelatonBib::DocumentIdentifier.new(type: "IETF", id: id)
        ret + reference.xpath("./seriesinfo").map do |si|
          next unless si[:name] == "DOI"

          RelatonBib::DocumentIdentifier.new(id: si[:value], type: si[:name])
        end.compact
      end

      #
      # Extract series form reference
      # @param reference [Nokogiri::XML::Document]
      #
      # @return [Array<RelatonBib::Series>]
      #
      def series(reference)
        reference.xpath("./seriesinfo").map do |si|
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
      # @param reference [Nokogiri::XML::Document]
      #
      # @return [RelatonBib::DocumentStatus]
      #
      def status(reference)
        st = reference.at("./seriesinfo[@status]")
        return unless st

        RelatonBib::DocumentStatus.new(
          stage: st[:status],
        )
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
