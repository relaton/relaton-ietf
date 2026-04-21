module Relaton
  module Ietf
    class ItemBase < Lutaml::Model::Serializable
      include Bib::NamespaceHelper

      attr_accessor :type

      model ItemData

      instance_exec(&Bib::ItemShared::ATTRIBUTES)

      xml do
        map_attribute "type", to: :type
        instance_exec(&Bib::ItemShared::XML_BODY)
      end
    end
  end
end
