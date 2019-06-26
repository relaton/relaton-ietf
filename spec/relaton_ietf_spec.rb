# frozen_string_literal: true

require "relaton_ietf"
require "date"

RSpec.describe RelatonIetf do
  it "has a version number" do
    expect(RelatonIetf::VERSION).not_to be nil
  end

  it "get RFC document" do
    VCR.use_cassette "rfc_8341" do
      item = RelatonIetf::IetfBibliography.search "RFC 8341"
      expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
      file = "spec/examples/bib_item.xml"
      xml = item.to_xml bibdata: true
      File.write file, xml unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file).sub(
        %r{<fetched>\d\d\d\d-\d\d-\d\d</fetched>}, "<fetched>#{Date.today}</fetched>"
      )
    end
  end

  it "get internet draft document" do
    VCR.use_cassette "i_d_burger_xcon_mmodels" do
      item = RelatonIetf::IetfBibliography.search "I-D.-burger-xcon-mmodels"
      expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
      file = "spec/examples/i_d_bib_item.xml"
      File.write file, item.to_xml unless File.exist? file
      expect(item.to_xml).to be_equivalent_to File.read(file).sub(
        %r{<fetched>\d\d\d\d-\d\d-\d\d</fetched>}, "<fetched>#{Date.today}</fetched>"
      )
    end
  end

  it "deals with extraneous prefix" do
    expect do
      RelatonIetf::IetfBibliography.get "W3C 8341"
    end.to raise_error RelatonBib::RequestError
  end

  it "deals with non-existent document" do
    VCR.use_cassette "non_existed_doc" do
      expect do
        RelatonIetf::IetfBibliography.search "RFC 08341"
      end.to raise_error RelatonBib::RequestError
    end
  end

  it "create RelatonIetf::IetfBibliographicItem from xml" do
    xml = File.read "spec/examples/bib_item.xml"
    item = RelatonIetf::XMLParser.from_xml xml
    expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
    expect(item.to_xml bibdata: true).to be_equivalent_to xml
  end
end
