module RelatonIetf
  class HashConverter < RelatonBib::HashConverter
    class << self
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
    end
  end
end
