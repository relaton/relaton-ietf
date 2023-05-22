require "relaton/processor"
require "relaton_ietf/xml_parser"

module RelatonIetf
  class Processor < Relaton::Processor
    def initialize # rubocop:disable Lint/MissingSuper
      @short = :relaton_ietf
      @prefix = "IETF"
      @defaultprefix = /^((IETF|RFC|BCP|FYI|STD)\s|I-D[.\s])/
      @idtype = "IETF"
      @datasets = %w[ietf-rfcsubseries ietf-internet-drafts ietf-rfc-entries]
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonIetf::IetfBibliographicItem]
    def get(code, date, opts)
      ::RelatonIetf::IetfBibliography.get(code, date, opts)
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
      DataFetcher.fetch(source, **opts)
    end

    # @param xml [String]
    # @return [RelatonIetf::IetfBibliographicItem]
    def from_xml(xml)
      ::RelatonIetf::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonIetf::IetfBibliographicItem]
    def hash_to_bib(hash)
      ::RelatonIetf::IetfBibliographicItem.from_hash hash
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonIetf.grammar_hash
    end

    #
    # Remove index file
    #
    def remove_index_file
      Relaton::Index.find_or_create(:RFC, url: true, file: Scrapper::INDEX_FILE).remove_file
      Relaton::Index.find_or_create(:RSS, url: true, file: Scrapper::INDEX_FILE).remove_file
      Relaton::Index.find_or_create(:IDS, url: true, file: Scrapper::INDEX_FILE).remove_file
    end
  end
end
