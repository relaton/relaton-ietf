module RelatonIetf
  class IetfBibliographicItem < RelatonBib::BibliographicItem
    # @return [String, nil]
    attr_reader :stream

    # @return [Array<String>]
    attr_reader :keyword

    # @param keyword [Array<String>]
    # @param stream [String, nil]
    def initialize(**args)
      @stream = args.delete(:stream)
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
    # @option opts [Symbol, nil] :date_format (:short), :full
    # @option opts [String, Symbol] :lang language
    # @return [String] XML
    def to_xml(**opts) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
      opts[:date_format] ||= :short
      super(**opts) do |builder|
        if opts[:bibdata] && (doctype || editorialgroup || ics&.any? ||
          structuredidentifier&.presence? || stream)
          ext = builder.ext do |b|
            doctype&.to_xml b
            b.subdoctype subdoctype if subdoctype
            editorialgroup&.to_xml b
            ics.each { |i| i.to_xml b }
            b.stream stream if stream
            structuredidentifier&.to_xml b
          end
          ext["schema-version"] = ext_schema if !opts[:embedded] && respond_to?(:ext_schema)
        end
      end
    end

    #
    # Render hash
    #
    # @return [Hash] docunent hash representation
    #
    def to_hash(embedded: false)
      hash = super
      return hash unless stream

      hash["ext"] ||= {}
      hash["ext"]["stream"] = stream
      hash
    end

    def has_ext?
      super || stream
    end

    #
    # Render BibXML (RFC)
    #
    # @param [Nokogiri::XML::Builder, nil] builder
    # @param [Boolean] include_keywords (false)
    #
    # @return [String, Nokogiri::XML::Builder::NodeBuilder] XML
    #
    def to_bibxml(builder = nil, include_keywords: false)
      Renderer::BibXML.new(self).render builder: builder, include_keywords: include_keywords
    end
  end
end
