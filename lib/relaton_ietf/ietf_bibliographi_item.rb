module RelatonIetf
  class IetfBibliographicItem < RelatonBib::BibliographicItem
    # @return [String, NilClass]
    attr_reader :doctype

    # @return [Array<String>]
    attr_reader :keywords

    # @param doctype [String]
    # @param keywords [Array<String>]
    def initialize(**args)
      @doctype = args.delete :doctype
      @keywords = args.delete(:keywords) || []
      super
    end

    # @param builder
    # @param opts [Hash]
    # @option opts [Symbol, NilClass] :date_format (:short), :full
    def to_xml(builder = nil, **opts)
      opts[:date_format] ||= :short
      super builder, **opts do |b|
        if opts[:bibdata]
          b.ext do
            b.doctype doctype if doctype
            keywords.each { |k| b.keyword k }
          end
        end
      end
    end
  end
end
