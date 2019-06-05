require "relaton/processor"
require "relaton_ietf/xml_parser"

module Relaton
  module RelatonIetf
    class Processor < Relaton::Processor
      def initialize
        @short = :relaton_ietf
        @prefix = "IETF"
        @defaultprefix = /^RFC /
        @idtype = "IETF"
      end

      def get(code, date, opts)
        ::RelatonIetf::IetfBibliography.get(code, date, opts)
      end

      def from_xml(xml)
        ::RelatonIetf::XMLParser.from_xml xml
      end
    end
  end
end
