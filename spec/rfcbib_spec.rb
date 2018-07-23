# frozen_string_literal: true

require 'rfcbib'

RSpec.describe Rfcbib do
  it 'has a version number' do
    expect(Rfcbib::VERSION).not_to be nil
  end

  it 'get RFC document' do
    stub_net_http 'rfc_8341'
    item = RfcBib::RfcBibliography.search 'RFC 8341'
    expect(item).to be_instance_of IsoBibItem::BibliographicItem
    file = 'spec/examples/bib_item.xml'
    File.write file, item.to_xml unless File.exist? file
    expect(item.to_xml).to be_equivalent_to File.read file
  end

  it 'get internet draft document' do
    stub_net_http 'i_d_burger_xcon_mmodels'
    item = RfcBib::RfcBibliography.search 'I-D.-burger-xcon-mmodels'
    expect(item).to be_instance_of IsoBibItem::BibliographicItem
    file = 'spec/examples/i_d_bib_item.xml'
    File.write file, item.to_xml unless File.exist? file
    expect(item.to_xml).to be_equivalent_to File.read file
  end

  private

  def stub_net_http(file_name)
    expect(Net::HTTP).to receive(:get).and_wrap_original do |m, *args|
      expect(args[0]).to be_instance_of URI::HTTPS
      file = "spec/examples/#{file_name}.xml"
      File.write file, m.call(*args) unless File.exist? file
      File.read file
    end
  end
end
