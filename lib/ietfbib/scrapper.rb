# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'iso_bib_item'

module IETFBib
  # rubocop:disable Metrics/ModuleLength

  # Scrapper module
  module Scrapper

    RFC_URI_PATTERN = "https://www.rfc-editor.org/refs/bibxml/reference.CODE"
    ID_URI_PATTERN = "https://xml2rfc.tools.ietf.org/public/rfc/bibxml-ids/reference.CODE"

    class << self
      # @param text [String]
      # @return [IsoBibItem::BibliographicItem]
      def scrape_page(text)

        # Remove initial "IETF " string if specified
        ref = text.
          gsub(/^IETF /, "").
          sub(' ', '.') + '.xml'

        uri = case ref
        when /^RFC/
          RFC_URI_PATTERN.dup
        when /^I-D/
          ID_URI_PATTERN.dup
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
          @reference = doc.at('//reference')
          return unless @reference
          bib_item
        rescue
          warn "No document found at #{uri}"
        end
      end

      private

      # rubocop:disable Metrics/MethodLength

      # @return [IsoBibItem::BibliographicItem]
      def bib_item
        IsoBibItem::BibliographicItem.new(
          id: @reference[:anchor],
          docid: docids(@reference[:anchor].sub(/^(RFC)/, "\\1 ")),
          status: status,
          language: [language],
          link: [{ type: 'src', content: @reference[:target] }],
          titles: titles,
          contributors: contributors,
          dates: dates,
          series: series
        )
      end
      # rubocop:enable Metrics/MethodLength

      # @return [String]
      def language
        @reference[:lang] || 'en'
      end

      # @return [Array<Hash>]
      def titles
        title = @reference.at('//front/title')
        [{ content: title.text, language: language, script: 'Latn' }]
      end

      # @return [Array<Hash>]
      def contributors
        persons + organizations
      end

      # @return [Array<Hash{Symbol=>IsoBibItem::Person,Symbol=>Array<String>}>]
      def persons
        @reference.xpath('//front/author').map do |author|
          entity = IsoBibItem::Person.new(
            name: full_name(author),
            affiliation: [affiliation(author)],
            contacts: contacts(author.at('//address'))
          )
          { entity: entity, roles: [contributor_role(author)] }
        end
      end

      # @return [Array<Hash{Symbol=>IsoBibItem::Organization,Symbol=>Array<String>}>]
      def organizations
        @reference.xpath('//seriesinfo').map do |si|
          next unless si[:stream]
          entity = IsoBibItem::Organization.new name: si[:stream]
          { entity: entity, roles: ['author'] }
        end.compact
      end

      # @param author [Nokogiri::XML::Document]
      # @return [IsoBibItem::FullName]
      def full_name(author)
        IsoBibItem::FullName.new(
          completename: localized_string(author[:fullname]),
          initials: [localized_string(author[:initials])],
          surname: [localized_string(author[:surname])]
        )
      end

      # @param content [String]
      # @return [IsoBibItem::LocalizedString]
      def localized_string(content)
        IsoBibItem::LocalizedString.new(content, language)
      end

      # @param postal [Nokogiri::XML::Document]
      # @return [Array<IsoBibItem::Address, IsoBibItem::Phone>]
      def contacts(addr)
        contacts = []
        return contacts unless addr
        postal = addr.at('//postal')
        contacts << address(postal) if postal
        add_contact(contacts, 'phone', addr.at('//phone'))
        add_contact(contacts, 'email', addr.at('//email'))
        add_contact(contacts, 'uri', addr.at('//uri'))
        contacts
      end

      # @param postal [Nokogiri::XML::Document]
      # @rerurn [IsoBibItem::Address]
      def address(postal)
        IsoBibItem::Address.new(
          street: [(postal.at('//postalLine') || postal.at('//street')).text],
          city: postal.at('//city').text,
          postcode: postal.at('//code').text,
          country: postal.at('//country').text,
          state: postal.at('//region').text
        )
      end

      # @param type [String] allowed "phone", "email" or "uri"
      # @param value [String]
      def add_contact(contacts, type, value)
        return unless value
        contacts << IsoBibItem::Contact.new(type: type, value: value.text)
      end

      # @param author [Nokogiri::XML::Document]
      # @return [IsoBibItem::Affilation]
      def affiliation(author)
        organization = author.at('//organization')
        IsoBibItem::Affilation.new IsoBibItem::Organization.new(
          name: organization.text.empty? ? 'IETF' : organization.text,
          abbreviation: organization[:abbrev] || 'IETF'
        )
      end

      # @param author [Nokogiri::XML::Document]
      # @return [String]
      def contributor_role(author)
        author[:role] || 'author'
      end

      def month(mo)
        return mo if /^\d+$/.match mo
        Date::MONTHNAMES.index(mo)
      end

      #
      # Extract date from reference.
      #
      # @return [Array<IsoBibItem::BibliographicDate>] published data.
      #
      def dates
        return unless (date = @reference.at '//front/date')
        d = [date[:year], month(date[:month]),
             (date[:day] || "01")].compact.join '-'
        date = Time.parse(d).strftime '%Y-%m-%d'
        [IsoBibItem::BibliographicDate.new(type: 'published', on: date)]
      end

      #
      # Extract document identifiers from reference
      #
      # @return [Array<IsoBibItem::DocumentIdentifier>]
      #
      def docids(id)
        ret = []
        ret << IsoBibItem::DocumentIdentifier.new(type: "IETF", id: id)
        ret = ret + @reference.xpath('//seriesinfo').map do |si|
          next unless si[:name] == 'DOI'
          IsoBibItem::DocumentIdentifier.new(id: si[:value], type: si[:name])
        end.compact
      end

      #
      # Extract series form reference
      #
      # @return [Array<IsoBibItem::FormattedString>]
      #
      def series
        @reference.xpath('//seriesinfo').map do |si|
          next if si[:name] == 'DOI' || si[:stream] || si[:status]
          IsoBibItem::Series.new(
            title: IsoBibItem::FormattedString.new(
              content: si[:name], language: language, script: 'Latn'
            ),
            number: si[:value],
            type: "main"
          )
        end.compact
      end

      #
      # extract status
      #
      # @return [IsoBibItem::DocumentStatus]
      #
      def status
        st = @reference.at('//seriesinfo[@status]')
        return unless st
        IsoBibItem::DocumentStatus.new(
          IsoBibItem::LocalizedString.new(st[:status])
        )
      end
    end
  end
  # rubocop:enable Metrics/ModuleLength
end
