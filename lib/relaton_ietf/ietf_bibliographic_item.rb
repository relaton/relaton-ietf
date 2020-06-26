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
      # @doctype = args[:doctype]
    end

    # @param builder
    # @param opts [Hash]
    # @option opts [Symbol, NilClass] :date_format (:short), :full
    def to_xml(builder = nil, **opts)
      opts[:date_format] ||= :short
      super builder, **opts do |b|
        if opts[:bibdata] && doctype
          b.ext do
            b.doctype doctype if doctype
          end
        end
      end
    end

    # @return [Hash]
    def to_hash
      hash = super
      hash["doctype"] = doctype if doctype
      # hash["keyword"] = single_element_array(keyword) if keyword&.any?
      hash
    end
  end
end
