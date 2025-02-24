module Relaton
  module Ietf
    class EditorialGroup < Lutaml::Model::Serializable
      attribute :committee, Bib::WorkGroup, collection: true

      xml do
        map_element "committee", to: :committee
      end
    end
  end
end
