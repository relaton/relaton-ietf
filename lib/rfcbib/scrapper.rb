# frozen_string_literal: true

require 'net/http'
require 'nokogiri'
require 'iso_bib_item'

module RfcBib
  # Scrapper module
  module Scrapper
    class << self
      # @param text [String]
      # @return [IsoBibItem::BibliographicItem]
      def scrape_page(text)
        # ref = text.downcase.delete ' '
        ref = text.sub(' ', '.') + '.xml'
        # html = Net::HTTP.get URI("https://www.rfc-editor.org/info/#{ref}")
        uri = URI("https://www.rfc-editor.org/refs/bibxml/reference.#{ref}")
        xml = Net::HTTP.get uri
        doc = Nokogiri::HTML xml
        @reference = doc.at('//reference')
        return unless @reference
        bib_item
      end

      private

      # @return [IsoBibItem::BibliographicItem]
      def bib_item
        IsoBibItem::BibliographicItem.new(
          id: @reference[:anchor],
          language: [language],
          # docid: { project_number: reference[:anchor], part_number: '' },
          source: [{ type: 'src', content: @reference[:target] }],
          titles: titles,
          contributors: contributors,
          dates: dates
        )
      end

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
        @reference.xpath('//front/author').map do |author|
          entity = IsoBibItem::Person.new(
            name: full_name(author),
            affilation: [affilation(author)],
            contacts: contacts(author.at('//address'))
          )
          { entity: entity, roles: [contributor_role(author)] }
        end
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
      def affilation(author)
        organization = author.at('//organization')
        IsoBibItem::Affilation.new IsoBibItem::Organization.new(
          name: organization.text || 'IETF',
          abbreviation: organization[:abbrev] || 'IETF'
        )
      end

      # @param author [Nokogiri::XML::Document]
      # @return [String]
      def contributor_role(author)
        author[:role] || 'author'
      end

      #
      # Extract date from reference.
      #
      # @return [<Type>] <description>
      #
      def dates
        return unless (date = @reference.at '//front/date')
        d = [date[:year], date[:month], date[:day]].compact.join '-'
        date = Time.parse(d).strftime '%Y-%m-%d'
        [IsoBibItem::BibliographicDate.new(type: 'published', on: date)]
      end
    end
  end
end
