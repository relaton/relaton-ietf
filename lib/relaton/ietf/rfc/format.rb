# frozen_string_literal: true

require_relative "rfc_index_namespace"

module Relaton
  module Ietf
    module Rfc
      class Format < Lutaml::Model::Serializable
        attribute :file_format, :string, collection: true

        xml do
          root "format"
          namespace RfcIndexNamespace
          map_element "file-format", to: :file_format
        end
      end
    end
  end
end
