module RelatonIetf
  class HashConverter < RelatonBib::HashConverter
    class << self
      # @override RelatonBib::HashConverter.hash_to_bib
      # @param args [Hash]
      # @param nested [TrueClass, FalseClass]
      # @return [Hash]
      # def hash_to_bib(args, nested = false)
      #   ret = super
      #   return if ret.nil?

      #   doctype_hash_to_bib(ret)
      #   ret
      # end

      # private

      # def doctype_hash_to_bib(ret)
      #   ret
      # end
    end
  end
end
