# frozen_string_literal: true

module Relaton
  module Ietf
    module Rfc
      class Author < Lutaml::Model::Serializable
        attribute :name, :string
        attribute :role_title, :string

        xml do
          root "author"
          namespace "https://www.rfc-editor.org/rfc-index"
          map_element "name", to: :name
          map_element "title", to: :role_title
        end
      end
    end
  end
end
