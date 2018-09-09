require 'relaton/processor'

module Relaton
  module IETFBib
    class Processor < Relaton::Processor
      def initialize
        @short = :rfcbib
        @prefix = "IETF"
        @defaultprefix = /^RFC /
      end

      def get(code, date, opts)
        ::IETFBib::RfcBibliography.get(code, date, opts)
      end
    end
  end
end
