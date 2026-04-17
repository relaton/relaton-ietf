module Relaton
  module Ietf
    class Bibitem < Item
      model ItemData
      include Bib::BibitemShared
    end
  end
end
