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

    # @param hash [Hash]
    # @return [RelatonIetf::IetfBibliographicItem]
    def self.from_hash(hash)
      item_hash = ::RelatonIetf::HashConverter.hash_to_bib(hash)
      new **item_hash
    end

    # @param opts [Hash]
    # @option opts [Nokogiri::XML::Builder] :builder XML builder
    # @option opts [Boolean] :bibdata
    # @option opts [Symbol, NilClass] :date_format (:short), :full
    # @option opts [String, Symbol] :lang language
    # @return [String] XML
    def to_xml(**opts)
      opts[:date_format] ||= :short
      super **opts
    end
  end
end
