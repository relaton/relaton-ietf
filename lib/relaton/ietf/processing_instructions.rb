module Relaton
  module Ietf
    class ProcessingInstructions < Lutaml::Model::Serializable
      attribute :artworkdelimiter, :string
      attribute :artworklines, :string
      attribute :authorship, :string
      attribute :autobreaks, :string
      attribute :background, :string
      attribute :colonspace, :string
      attribute :comments, :string
      attribute :docmapping, :string
      attribute :editing, :string
      attribute :emoticonic, :string
      attribute :footer, :string
      attribute :header, :string
      attribute :inline, :string
      attribute :iprnotified, :string
      attribute :linkmailto, :string
      attribute :linefile, :string
      attribute :notedraftinprogress, :string
      attribute :private, :string
      attribute :refparent, :string
      attribute :rfcedstyle, :string
      attribute :slides, :string
      attribute :text_list_symbols, :string
      attribute :tocappendix, :string
      attribute :tocindent, :string
      attribute :tocnarrow, :string
      attribute :tocompact, :string
      attribute :topblock, :string
      attribute :useobject, :string
      attribute :strict, :string
      attribute :compact, :string
      attribute :subcompact, :string
      attribute :tocinclude, :string
      attribute :tocdepth, :string
      attribute :symrefs, :string
      attribute :sortrefs, :string

      xml do
        map_element "artworkdelimiter", to: :artworkdelimiter
        map_element "artworklines", to: :artworklines
        map_element "authorship", to: :authorship
        map_element "autobreaks", to: :autobreaks
        map_element "background", to: :background
        map_element "colonspace", to: :colonspace
        map_element "comments", to: :comments
        map_element "docmapping", to: :docmapping
        map_element "editing", to: :editing
        map_element "emoticonic", to: :emoticonic
        map_element "footer", to: :footer
        map_element "header", to: :header
        map_element "inline", to: :inline
        map_element "iprnotified", to: :iprnotified
        map_element "linkmailto", to: :linkmailto
        map_element "linefile", to: :linefile
        map_element "notedraftinprogress", to: :notedraftinprogress
        map_element "private", to: :private
        map_element "refparent", to: :refparent
        map_element "rfcedstyle", to: :rfcedstyle
        map_element "slides", to: :slides
        map_element "text-list-symbols", to: :text_list_symbols
        map_element "tocappendix", to: :tocappendix
        map_element "tocindent", to: :tocindent
        map_element "tocnarrow", to: :tocnarrow
        map_element "tocompact", to: :tocompact
        map_element "topblock", to: :topblock
        map_element "useobject", to: :useobject
        map_element "strict", to: :strict
        map_element "compact", to: :compact
        map_element "subcompact", to: :subcompact
        map_element "tocinclude", to: :tocinclude
        map_element "tocdepth", to: :tocdepth
        map_element "symrefs", to: :symrefs
        map_element "sortrefs", to: :sortrefs
      end
    end
  end
end
