# frozen_string_literal: true

module Relaton
  module Ietf
    module Rfc
      class Keywords < Lutaml::Model::Serializable
        attribute :kw, :string, collection: true

        xml do
          root "keywords"
          namespace "https://www.rfc-editor.org/rfc-index"
          map_element "kw", to: :kw
        end
      end
    end
  end
end
