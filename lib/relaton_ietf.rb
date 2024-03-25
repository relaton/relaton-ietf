# frozen_string_literal: true

require "net/http"
require "relaton/index"
require "relaton_bib"
require "relaton_ietf/version"
require "relaton_ietf/util"
require "relaton_ietf/document_type"
require "relaton_ietf/bibxml_parser"
require "relaton_ietf/ietf_bibliography"
require "relaton_ietf/xml_parser"
require "relaton_ietf/hash_converter"
require "relaton_ietf/data_fetcher"
require "relaton_ietf/renderer/bibxml"
require "relaton/provider_ietf"

module RelatonIetf
  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    # gem_path = File.expand_path "..", __dir__
    # grammars_path = File.join gem_path, "grammars", "*"
    # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest RelatonIetf::VERSION + RelatonBib::VERSION # grammars
  end
end
