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

    # @param builder
    # @param opts [Hash]
    # @option opts [Symbol, NilClass] :date_format (:short), :full
    def to_xml(builder = nil, **opts)
      opts[:date_format] ||= :short
      super builder, **opts
    end
  end
end
