# frozen_string_literal: true

require_relative "rfc_index_namespace"

module Relaton
  module Ietf
    module Rfc
      class Keywords < Lutaml::Model::Serializable
        attribute :kw, :string, collection: true

        xml do
          root "keywords"
          namespace RfcIndexNamespace
          map_element "kw", to: :kw
        end
      end
    end
  end
end
