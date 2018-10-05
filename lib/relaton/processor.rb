require 'relaton/processor'
require 'ietfbib/xml_parser'

module Relaton
  module IETFBib
    class Processor < Relaton::Processor
      def initialize
        @short = :rfcbib
        @prefix = "IETF"
        @defaultprefix = /^RFC /
        @idtype = "IETF"
      end

      def get(code, date, opts)
        ::IETFBib::RfcBibliography.get(code, date, opts)
      end

      def from_xml(xml)
        ::IETFBib::XMLParser.from_xml xml
      end
    end
  end
end
