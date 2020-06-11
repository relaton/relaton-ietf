# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "relaton_bib"
require "relaton_ietf/ietf_bibliographic_item"

module RelatonIetf
  # rubocop:disable Metrics/ModuleLength

  # Scrapper module
  module Scrapper
    RFC_URI_PATTERN = "https://xml2rfc.tools.ietf.org/public/rfc/bibxml"
    # ID_URI_PATTERN = "https://xml2rfc.tools.ietf.org/public/rfc/bibxml-ids/reference.CODE"
    BCP_URI_PATTERN = "https://www.rfc-editor.org/info/CODE"

    class << self
      # rubocop:disable Metrics/MethodLength

      # @param text [String]
      # @param is_relation [TrueClass, FalseClass]
      # @return [RelatonIetf::IetfBibliographicItem]
      def scrape_page(text, is_relation = false)
        # Remove initial "IETF " string if specified
        ref = text.gsub(/^IETF /, "")

        case ref
        when /^RFC/ then rfc_item [""], ref, is_relation
        when /^I-D/ then rfc_item ["3"], ref, is_relation
        when /^W3C/ then rfc_item ["4", "2"], ref, is_relation
        when /^(ANSI|CCITT|FIPS|IANA|ISO|ITU|NIST|OASIS|PKCS)/
          rfc_item ["2"], ref, is_relation
        when /^(3GPP|SDO-3GPP)/ then rfc_item ["5"], ref, is_relation
        when /^IEEE/ then rfc_item ["6", "2"], ref, is_relation
        when /^BCP/ then bcp_item BCP_URI_PATTERN.dup, ref
        else
          raise RelatonBib::RequestError, "#{ref}: not recognised for RFC"
        end
      rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
             Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
             Net::ProtocolError, SocketError
        raise RelatonBib::RequestError, "No document found for #{ref} reference."
      end

      # @param reference [String]
      # @param is_relation [TrueClass, FalseClass]
      # @param url [String, NilClass]
      # @param ver [String, NilClass] Internet Draft version
      # @return [RelatonIetf::IetfBibliographicItem]
      def fetch_rfc(reference, is_relation = false, url = nil, ver = nil)
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
          abstract: abstracts(reference),
          contributor: contributors(reference),
          date: dates(reference),
          series: series(reference),
          place: ["Fremont, CA"],
          keyword: reference.xpath("front/keyword").map(&:text),
          doctype: doctype(reference[:anchor]),
        )
      end
      # rubocop:enable Metrics/MethodLength

      private

      # @param anchor [String]
      # @return [String]
      def doctype(anchor)
        anchor =~ /I-D/ ? "internet-draft" : "rfc"
      end

      # @param reference [Nokogiri::XML::Element]
      # @param url [String]
      # @param ver [String, NilClass] Internet Draft version
      # @return [Array<Hash>]
      def link(reference, url, ver)
        l = []
        l << { type: "xml", content: url } if url
        l << { type: "src", content: reference[:target] } if reference[:target]
        if reference[:anchor] =~ /^I-D/
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

      # @param uri_nums [Array<String>]
      # @param ref [String]
      # @return [RelatonIetf::IetfBibliographicItem]
      def rfc_item(uri_nums, ref, is_relation)
        uri = nil
        error = nil
        uri_nums.each do |n|
          /(?<=-)(?<ver>\d{2})$/ =~ ref
          ref.sub! /-\d{2}/, "" if ver && n == "3"

          uri = "#{RFC_URI_PATTERN}#{n}/reference.#{ref.sub(/\s|\u00a0/, ".")}.xml"
          begin
            doc = Nokogiri::XML get_page(uri)
            resp = fetch_rfc doc.at("//reference"), is_relation, uri, ver
            return resp if resp
          rescue RelatonBib::RequestError => e
            error = e
          end
        end
        raise error
      end

      # @param uri_template [String]
      # @param reference [String]
      # @return [RelatonIetf::IetfBibliographicItem]
      def bcp_item(uri_template, reference)
        uri = uri_template.sub "CODE", reference.sub(" ", "").downcase
        doc = Nokogiri::HTML get_page(uri)
        ietf_item(
          id: reference,
          title: [content: ""],
          docid: [RelatonBib::DocumentIdentifier.new(type: "IETF", id: reference)],
          language: ["en"],
          link: [{ type: "src", content: uri }],
          relation: fetch_relations(doc),
          doctype: "rfc",
        )
      end

      def fetch_relations(doc)
        doc.xpath("//table/tr/td/a[contains(., 'RFC')]").map do |r|
          RelatonBib::DocumentRelation.new(
            type: "merges",
            bibitem: scrape_page(r.text, true),
          )
        end
      end

      def get_page(uri)
        res = Net::HTTP.get_response(URI(uri))
        if res.code != "200"
          raise RelatonBib::RequestError, "No document found at #{uri}"
        end

        res.body
      end

      # def make_uri(uri_template, reference)
      #   uri_template.gsub("CODE", reference)
      # end

      # @return [String]
      def language(reference)
        reference[:lang] || "en"
      end

      # @return [Array<Hash>]
      def titles(reference)
        title = reference.at("./front/title")
        [{ content: title.text, language: language(reference), script: "Latn" }]
      end

      # @return [Array<RelatonBib::FormattedString>]
      def abstracts(ref)
        ref.xpath("./front/abstract").map do |a|
          RelatonBib::FormattedString.new(
            content: a.text.gsub(/\\n\\t{2,4}/, " ").strip,
            language: language(ref), script: "Latn"
          )
        end
      end

      # @return [Array<Hash>]
      def contributors(reference)
        persons(reference) + organizations(reference)
      end

      # @return [Array<Hash{Symbol=>RelatonBib::Person,Symbol=>Array<String>}>]
      def persons(reference)
        reference.xpath("./front/author[@surname]|./front/author[@fullname]").
          map do |author|
          entity = RelatonBib::Person.new(
            name: full_name(author, reference),
            affiliation: [affiliation(author)],
            contact: contacts(author.at("./address")),
          )
          { entity: entity, role: [contributor_role(author)] }
        end
      end

      # @return [Array<Hash{Symbol=>RelatonBib::Organization,Symbol=>Array<String>}>]
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

      # @param author [Nokogiri::XML::Document]
      # @param ref [Nokogiri::XML::Document]
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
             (date[:day] || 1)].compact.join "-"
        date = Time.parse(d).strftime "%Y-%m-%d"
        [RelatonBib::BibliographicDate.new(type: "published", on: date)]
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize

      #
      # Extract document identifiers from reference
      #
      # @param reference [Nokogiri::XML::Element]
      # @param ver [String, NilClass] Internet Draft version
      #
      # @return [Array<RelatonBib::DocumentIdentifier>]
      #
      def docids(reference, ver)
        id = (reference[:anchor] || reference[:docName] || reference[:number]).
          sub(/^(RFC)/, "\\1 ")
        ret = []
        ret << RelatonBib::DocumentIdentifier.new(type: "IETF", id: id)
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
      # enable Metrics/MethodLength, Metrics/AbcSize

      #
      # Extract series form reference
      # @param reference [Nokogiri::XML::Document]
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
