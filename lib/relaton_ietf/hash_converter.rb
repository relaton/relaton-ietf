module RelatonIetf
  module HashConverter
    include RelatonBib::HashConverter
    extend self
    def hash_to_bib(hash)
      ret = super
      return unless ret

      stream_hash_to_bib ret
      ret
    end

    #
    # Ovverides superclass's method
    #
    # @param item [Hash]
    # @retirn [RelatonIetf::IetfBibliographicItem]
    def bib_item(item)
      IetfBibliographicItem.new(**item)
    end

    # @param ret [Hash]
    def editorialgroup_hash_to_bib(ret)
      return unless ret[:editorialgroup]

      technical_committee = RelatonBib.array(ret[:editorialgroup]).map do |wg|
        Committee.new RelatonBib::WorkGroup.new(**wg)
      end
      ret[:editorialgroup] = RelatonBib::EditorialGroup.new technical_committee
    end

    def stream_hash_to_bib(ret)
      ret[:stream] = ret[:ext][:stream] if ret[:ext]&.key? :stream
    end

    def create_doctype(**args)
      DocumentType.new(**args)
    end
  end
end
