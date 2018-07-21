# frozen_string_literal: true

require 'rfcbib/version'
require 'rfcbib/rfc_bibliography'

if defined? Relaton
  require_relative 'relaton/processor'
  Relaton::Registry.instance.register(Relaton::RfcBib::Processor)
end
