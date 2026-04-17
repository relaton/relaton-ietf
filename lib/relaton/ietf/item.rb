require_relative "ext"

module Relaton
  module Ietf
    class Item < Bib::Item
      model ItemData

      attribute :ext, Ext
    end
  end
end

require_relative "relation"

Relaton::Ietf::Item.attribute :relation, Relaton::Ietf::Relation,
                              collection: true, initialize_empty: true
