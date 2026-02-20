require "relaton/core/processor"
require_relative "../ietf"

module Relaton
  module Ietf
    class Processor < Relaton::Core::Processor
      def initialize # rubocop:disable Lint/MissingSuper
        @short = :relaton_ietf
        @prefix = "IETF"
        @defaultprefix = /^((IETF|RFC|BCP|FYI|STD)\s|I-D[.\s])/
        @idtype = "IETF"
        @datasets = %w[ietf-rfcsubseries ietf-internet-drafts ietf-rfc-entries]
      end

      # @param code [String]
      # @param date [String, nil] year
      # @param opts [Hash]
      # @return [Relaton::Ietf::ItemData, nil]
      def get(code, date, opts)
        Bibliography.get(code, date, opts)
      end

      #
      # Fetch all the documents from https://www.rfc-editor.org/rfc-index.xml
      #
      # @param [String] source source name
      # @param [Hash] opts
      # @option opts [String] :output directory to output documents
      # @option opts [String] :format
      #
      def fetch_data(source, opts)
        require_relative "../relaton_ietf/data_fetcher"
        DataFetcher.fetch(source, **opts)
      end

      # @param xml [String]
      # @return [Relaton::Ietf::ItemData]
      def from_xml(xml)
        Item.from_xml xml
      end

      # @param yaml [String]
      # @return [Relaton::Ietf::ItemData]
      def from_yaml(yaml)
        Item.from_yaml yaml
      end

      # Returns hash of XML grammar
      # @return [String]
      def grammar_hash
        @grammar_hash ||= ::Relaton::Ietf.grammar_hash
      end

      #
      # Remove index file
      #
      def remove_index_file
        Relaton::Index.find_or_create(:RFC, url: true, file: "#{INDEXFILE}.yaml").remove_file
        Relaton::Index.find_or_create(:RSS, url: true, file: "#{INDEXFILE}.yaml").remove_file
        Relaton::Index.find_or_create(:IDS, url: true, file: "#{INDEXFILE}.yaml").remove_file
      end
    end
  end
end
