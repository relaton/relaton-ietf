module Relaton
  module Ietf
    class Bibdata < Item
      model ItemData
      include Bib::BibdataShared
    end
  end
end
