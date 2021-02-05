module RelatonIetf
  class HashConverter < RelatonBib::HashConverter
    class << self
      #
      # Ovverides superclass's method
      #
      # @param item [Hash]
      # @retirn [RelatonIec::IecBibliographicItem]
      def bib_item(item)
        IecBibliographicItem.new(item)
      end
    end
  end
end
