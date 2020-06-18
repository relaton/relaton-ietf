module RelatonIetf
  class IetfBibliographicItem < RelatonBib::BibliographicItem
    # @return [String, NilClass]
    attr_reader :doctype

    # @return [Array<String>]
    attr_reader :keyword

    # @param doctype [String]
    # @param keyword [Array<String>]
    # def initialize(**args)
    #   @doctype = args.delete :doctype
    #   # @keyword = args.delete(:keyword) || []
    #   super
    # end

    # @param builder
    # @param opts [Hash]
    # @option opts [Symbol, NilClass] :date_format (:short), :full
    def to_xml(builder = nil, **opts)
      opts[:date_format] ||= :short
      super builder, **opts do |b|
        if opts[:bibdata]
          b.ext do
            b.doctype doctype if doctype
            # keyword.each { |k| b.keyword k }
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
