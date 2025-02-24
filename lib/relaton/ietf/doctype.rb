module Relaton
  module Ietf
    class Doctype < Bib::Doctype
      TYPES = %w[rfc internet-draft].freeze

      attribute :type, :string, values: TYPES
    end
  end
end
