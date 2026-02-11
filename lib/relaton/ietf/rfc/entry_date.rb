# frozen_string_literal: true

module Relaton
  module Ietf
    module Rfc
      class EntryDate < Lutaml::Model::Serializable
        attribute :month, :string
        attribute :year, :string

        xml do
          root "date"
          namespace "https://www.rfc-editor.org/rfc-index"
          map_element "month", to: :month
          map_element "year", to: :year
        end
      end
    end
  end
end
