# frozen_string_literal: true

require_relative "rfc_index_namespace"

module Relaton
  module Ietf
    module Rfc
      class EntryDate < Lutaml::Model::Serializable
        attribute :month, :string
        attribute :year, :string

        xml do
          root "date"
          namespace RfcIndexNamespace
          map_element "month", to: :month
          map_element "year", to: :year
        end
      end
    end
  end
end
