# frozen_string_literal: true

require_relative "rfc_index_namespace"

module Relaton
  module Ietf
    module Rfc
      # Model for <is-also> element containing doc-id references
      class IsAlso < Lutaml::Model::Serializable
        attribute :doc_id, :string, collection: true

        xml do
          root "is-also"
          namespace RfcIndexNamespace

          map_element "doc-id", to: :doc_id
        end
      end
    end
  end
end
