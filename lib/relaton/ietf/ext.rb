require_relative "doctype"
require_relative "editorial_group"
require_relative "processing_instructions"

module Relaton
  module Ietf
    class Ext < Lutaml::Model::Serializable
      attribute :schema_version, :string
      attribute :doctype, Doctype
      attribute :subdoctype, :string
      attribute :flavor, :string
      attribute :editorialgroup, EditorialGroup, collection: true
      attribute :ics, Bib::ICS, collection: true
      attribute :area, :string, collection: true, values: %W[
        apt gen int ops rtg sec tsv Applications\sand\sReal-Time General
        Internet Operations\sand\sManagement Routing Security Transport
      ]
      attribute :stream, :string, values: %w[IAB IETF Independent IRTF Legacy Editorial]
      attribute :ipr, :string
      attribute :consensus, :string
      attribute :index_include, :string
      attribute :ipr_extract, :string
      attribute :sort_refs, :string
      attribute :sym_refs, :string
      attribute :toc_include, :string
      attribute :toc_depth, :string
      attribute :show_on_front_page, :string
      attribute :pi, ProcessingInstructions

      xml do
        map_attribute "schema-version", to: :schema_version
        map_element "doctype", to: :doctype
        map_element "subdoctype", to: :subdoctype
        map_element "flavor", to: :flavor
        map_element "editorialgroup", to: :editorialgroup
        map_element "ics", to: :ics
        map_element "area", to: :area
        map_element "stream", to: :stream
        map_element "ipr", to: :ipr
        map_element "consensus", to: :consensus
        map_element "indexInclude", to: :index_include
        map_element "iprExtract", to: :ipr_extract
        map_element "sortRefs", to: :sort_refs
        map_element "symRefs", to: :sym_refs
        map_element "tocInclude", to: :toc_include
        map_element "tocDepth", to: :toc_depth
        map_element "showOnFrontPage", to: :show_on_front_page
        map_element "pi", to: :pi
      end
    end
  end
end
