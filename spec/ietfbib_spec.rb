# frozen_string_literal: true

require 'ietfbib'
require 'date'

RSpec.describe IETFBib do
  it 'has a version number' do
    expect(IETFBib::VERSION).not_to be nil
  end

  it 'get RFC document' do
    stub_net_http 'rfc_8341'
    item = IETFBib::RfcBibliography.search 'RFC 8341'
    expect(item).to be_instance_of IsoBibItem::BibliographicItem
    file = 'spec/examples/bib_item.xml'
    File.write file, item.to_xml unless File.exist? file
    expect(item.to_xml).to be_equivalent_to File.read(file).sub(/2018-10-04/, Date.today.to_s)
  end

  it 'get internet draft document' do
    stub_net_http 'i_d_burger_xcon_mmodels'
    item = IETFBib::RfcBibliography.search 'I-D.-burger-xcon-mmodels'
    expect(item).to be_instance_of IsoBibItem::BibliographicItem
    file = 'spec/examples/i_d_bib_item.xml'
    File.write file, item.to_xml unless File.exist? file
    expect(item.to_xml).to be_equivalent_to File.read(file).sub(/2018-10-04/, Date.today.to_s)
  end

  it 'deals with extraneous prefix' do
    item = IETFBib::RfcBibliography.search 'W3C 8341'
    expect(item).to be nil
  end

  it 'deals with non-existent document' do
    item = IETFBib::RfcBibliography.search 'RFC 08341'
    expect(item).to be nil
  end

  it 'create IsoBibItem::BibliographicItem from xml' do
    xml = File.read 'spec/examples/bib_item.xml'
    item = IETFBib::XMLParser.from_xml xml
    expect(item).to be_instance_of IsoBibItem::BibliographicItem
    expect(item.to_xml).to be_equivalent_to xml.sub(/2018-10-04/, Date.today.to_s)
  end

  private

  def stub_net_http(file_name)
    expect(Net::HTTP).to receive(:get).and_wrap_original do |m, *args|
      expect(args[0]).to be_instance_of URI::HTTPS
      file = "spec/examples/#{file_name}.xml"
      File.write file, m.call(*args) unless File.exist? file
      File.read(file)
    end
  end
end
