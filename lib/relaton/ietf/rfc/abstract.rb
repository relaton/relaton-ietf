# frozen_string_literal: true

require_relative "rfc_index_namespace"

module Relaton
  module Ietf
    module Rfc
      class Abstract < Lutaml::Model::Serializable
        attribute :p, :string, collection: true

        xml do
          root "abstract"
          namespace RfcIndexNamespace
          map_element "p", to: :p
        end
      end
    end
  end
end
