# frozen_string_literal: true

require 'ietfbib/version'
require 'ietfbib/rfc_bibliography'
require 'ietfbib/xml_parser'

if defined? Relaton
  require_relative 'relaton/processor'
  Relaton::Registry.instance.register(Relaton::IETFBib::Processor)
end
