# frozen_string_literal: true

module Relaton
  module Ietf
    module Rfc
      class Format < Lutaml::Model::Serializable
        attribute :file_format, :string, collection: true

        xml do
          root "format"
          namespace "https://www.rfc-editor.org/rfc-index"
          map_element "file-format", to: :file_format
        end
      end
    end
  end
end
