# frozen_string_literal: true

require_relative "rfc_index_namespace"
require_relative "entry"

module Relaton
  module Ietf
    module Rfc
      # Model for the root <rfc-index> element
      class Index < Lutaml::Model::Serializable
        attribute :bcp_entries, Entry, collection: true
        attribute :fyi_entries, Entry, collection: true
        attribute :std_entries, Entry, collection: true
        attribute :rfc_entries, Entry, collection: true

        xml do
          root "rfc-index"
          namespace RfcIndexNamespace

          map_element "bcp-entry", to: :bcp_entries
          map_element "fyi-entry", to: :fyi_entries
          map_element "std-entry", to: :std_entries
          map_element "rfc-entry", to: :rfc_entries
        end

        #
        # Get all subseries entries
        #
        # @return [Array<Entry>]
        #
        def subseries_entries
          (bcp_entries || []) + (fyi_entries || []) + (std_entries || [])
        end

        #
        # Get entries that have is-also references (can be converted to items)
        #
        # @return [Array<Entry>]
        #
        def parseable_entries
          subseries_entries.select(&:has_is_also?)
        end
      end
    end
  end
end
