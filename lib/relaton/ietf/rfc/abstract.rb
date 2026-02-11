# frozen_string_literal: true

module Relaton
  module Ietf
    module Rfc
      class Abstract < Lutaml::Model::Serializable
        attribute :p, :string, collection: true

        xml do
          root "abstract"
          namespace "https://www.rfc-editor.org/rfc-index"
          map_element "p", to: :p
        end
      end
    end
  end
end
