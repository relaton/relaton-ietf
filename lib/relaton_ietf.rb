# frozen_string_literal: true

require "relaton_ietf/version"
require "relaton_ietf/ietf_bibliography"
require "relaton_ietf/ietf_bibliographi_item"
require "relaton_ietf/xml_parser"

if defined? Relaton
  require_relative "relaton/processor"
  Relaton::Registry.instance.register(Relaton::RelatonIetf::Processor)
end

require "relaton/provider_ietf"
