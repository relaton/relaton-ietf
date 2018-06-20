# frozen_string_literal: true

require 'rfcbib'

RSpec.describe Rfcbib do
  it 'has a version number' do
    expect(Rfcbib::VERSION).not_to be nil
  end

  it 'get document' do
    expect(Net::HTTP).to receive(:get).and_wrap_original do |m, *args|
      expect(args[0]).to be_instance_of URI::HTTPS
      expect(args.size).to eq 1
      file = 'spec/examples/rfc_8341.xml'
      File.write file, m.call(*args) unless File.exist? file
      File.read file
    end
    item = RfcBib::RfcBibliography.search 'RFC 8341'
    expect(item).to be_instance_of IsoBibItem::BibliographicItem
    file = 'spec/examples/bib_item.xml'
    File.write file, item.to_xml unless File.exist? file
    expect(item.to_xml).to eq File.read file
  end
end
