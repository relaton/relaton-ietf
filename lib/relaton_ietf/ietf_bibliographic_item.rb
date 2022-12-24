module RelatonIetf
  class IetfBibliographicItem < RelatonBib::BibliographicItem
    DOCTYPES = %w[rfc internet-draft].freeze

    # @return [String, NilClass]
    attr_reader :doctype

    # @return [Array<String>]
    attr_reader :keyword

    # @param doctype [String]
    # @param keyword [Array<String>]
    def initialize(**args)
      if args[:doctype] && !DOCTYPES.include?(args[:doctype])
        warn "[relaton-ietf] WARNING: invalid doctype #{args[:doctype]}"
      end
      super
    end

    #
    # Fetch flavor schema version
    #
    # @return [String] schema version
    #
    def ext_schema
      @ext_schema ||= schema_versions["relaton-model-ietf"]
    end

    # @param hash [Hash]
    # @return [RelatonIetf::IetfBibliographicItem]
    def self.from_hash(hash)
      item_hash = ::RelatonIetf::HashConverter.hash_to_bib(hash)
      new(**item_hash)
    end

    # @param opts [Hash]
    # @option opts [Nokogiri::XML::Builder] :builder XML builder
    # @option opts [Boolean] :bibdata
    # @option opts [Symbol, NilClass] :date_format (:short), :full
    # @option opts [String, Symbol] :lang language
    # @return [String] XML
    def to_xml(**opts)
      opts[:date_format] ||= :short
      super(**opts)
    end

    #
    # Render date as BibXML. Override to skip IANA docidentifiers
    #
    # @param [Nokogiri::XML::Builder] builder xml builder
    #
    def render_date(builder)
      return if docidentifier.detect { |i| i.type == "IANA" }

      super
    end

    #
    # Render authors as BibXML. Override to skip "RFC Publisher" organization
    #
    # @param [Nokogiri::XML::Builder] builder xml builder
    #
    def render_authors(builder) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      contributor.each do |c|
        next if c.entity.is_a?(Organization) && c.entity.name.map(&:content).include?("RFC Publisher")

        builder.author do |xml|
          xml.parent[:role] = "editor" if c.role.detect { |r| r.type == "editor" }
          if c.entity.is_a?(Person) then render_person xml, c.entity
          else render_organization xml, c.entity, c.role
          end
          render_address xml, c
        end
      end
    end
  end
end
