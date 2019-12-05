# frozen_string_literal: true

require "relaton_ietf/version"
require "relaton_ietf/ietf_bibliography"
require "relaton_ietf/ietf_bibliographic_item"
require "relaton_ietf/xml_parser"
require "relaton_ietf/hash_converter"

# if defined? Relaton
#   require_relative "relaton_ietf/processor"
#   Relaton::Registry.instance.register(RelatonIetf::Processor)
# end

require "relaton/provider_ietf"

module RelatonIetf
  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    gem_path = File.expand_path "..", __dir__
    grammars_path = File.join gem_path, "grammars", "*"
    grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest grammars
  end
end