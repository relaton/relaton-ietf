# frozen_string_literal: true

require "net/http"
require "relaton/index"
require "relaton/bib"
require_relative "ietf/version"
require_relative "ietf/util"
require_relative "ietf/item_data"
require_relative "ietf/item"
require_relative "ietf/item_base"
require_relative "ietf/bibitem"
require_relative "ietf/bibdata"
require_relative "ietf/rfc/index"
require_relative "ietf/bibliography"

module Relaton
  module Ietf
    INDEXFILE = "index-v1".freeze
    # Returns hash of XML reammar
    # @return [String]
    def self.grammar_hash
      # gem_path = File.expand_path "..", __dir__
      # grammars_path = File.join gem_path, "grammars", "*"
      # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
      Digest::MD5.hexdigest Relaton::Ietf::VERSION + Relaton::Bib::VERSION # grammars
    end
  end
end
