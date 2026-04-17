# frozen_string_literal: true

require_relative "rfc_index_namespace"

module Relaton
  module Ietf
    module Rfc
      class Author < Lutaml::Model::Serializable
        attribute :name, :string
        attribute :role_title, :string

        xml do
          root "author"
          namespace RfcIndexNamespace
          map_element "name", to: :name
          map_element "title", to: :role_title
        end
      end
    end
  end
end
