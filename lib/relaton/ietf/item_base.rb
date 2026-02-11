require_relative "ext"

module Relaton
  module Ietf
    class ItemBase < Item
      include Bib::ItemBaseAttributes
    end
  end
end
