require 'relaton/processor'

module Relaton
  module RfcBib
    class Processor < Relaton::Processor
      def initialize
        @short = :rfcbib
        @prefix = /^(IETF Standard )?(RFC|I-D|I\.-D\.) /
      end

      def get(code, date, opts)
        ::RfcBib::RfcBibliography.get(code, date, opts)
      end
    end
  end
end
