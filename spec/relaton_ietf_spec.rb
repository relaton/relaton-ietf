# frozen_string_literal: true

require "relaton_ietf"
require "date"
require "jing"

RSpec.describe RelatonIetf do
  it "has a version number" do
    expect(RelatonIetf::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonIetf.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  context "get RFC document" do
    it "RFC 8341" do
      VCR.use_cassette "rfc_8341" do
        item = RelatonIetf::IetfBibliography.search "RFC 8341"
        expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
        file = "spec/examples/bib_item.xml"
        xml = item.to_xml bibdata: true
        File.write file, xml, encoding: "utf-8" unless File.exist? file
        expect(xml).to be_equivalent_to File.read(file, encoding: "utf-8").sub(
          %r{<fetched>\d\d\d\d-\d\d-\d\d</fetched>},
          "<fetched>#{Date.today}</fetched>",
        )
        schema = Jing.new "spec/examples/isobib.rng"
        errors = schema.validate file
        expect(errors).to eq []
      end
    end
  end

  it "get internet draft document" do
    VCR.use_cassette "i_d_burger_xcon_mmodels" do
      item = RelatonIetf::IetfBibliography.search "I-D.-burger-xcon-mmodels"
      expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
      file = "spec/examples/i_d_bib_item.xml"
      xml = item.to_xml bibdata: true
      File.write file, xml unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file).sub(
        %r{<fetched>\d{4}-\d{2}-\d{2}</fetched>},
        "<fetched>#{Date.today}</fetched>",
      )
      schema = Jing.new "spec/examples/isobib.rng"
      errors = schema.validate file
      expect(errors).to eq []
    end
  end

  it "get internet draft document with version" do
    VCR.use_cassette "I-D.abarth-cake-02" do
      item = RelatonIetf::IetfBibliography.get "I-D.abarth-cake-02"
      expect(item.docidentifier.detect { |di| di.type == "Internet-Draft" }.id)
        .to eq "draft-abarth-cake-02"
      expect(item.link.detect { |l| l.type == "TXT" }.content.to_s).to eq(
        "http://www.ietf.org/internet-drafts/draft-abarth-cake-02.txt",
      )
    end
  end

  it "get internet draft document by I-D.draft-* reference" do
    VCR.use_cassette "I-D.draft-ietf-calext-eventpub-extensions" do
      item = RelatonIetf::IetfBibliography.get(
        "I-D.draft-ietf-calext-eventpub-extensions-15",
      )
      expect(item.docidentifier.detect { |di| di.type == "Internet-Draft" }.id)
        .to eq("draft-ietf-calext-eventpub-extensions-15")
    end
  end

  it "get WC3 document" do
    VCR.use_cassette "w3c_cr_cdr_20070718" do
      item = RelatonIetf::IetfBibliography.search "W3C CR-CDR-20070718"
      expect(item.docidentifier[0].id).to eq "W3C CR-CDR-20070718"
    end
  end

  it "get WC3 document form the second page" do
    VCR.use_cassette "w3c_cr_rdf_schema" do
      item = RelatonIetf::IetfBibliography.search "W3C CR-rdf-schema"
      expect(item.docidentifier[0].id).to eq "W3C CR-rdf-schema"
    end
  end

  it "get ANSI document" do
    VCR.use_cassette "ansi_t1_102_1007" do
      file = "spec/examples/ansi_t1_102_1987.xml"
      item = RelatonIetf::IetfBibliography.search "ANSI T1-102.1987"
      xml = item.to_xml bibdata: true
      File.write file, xml, ecoding: "UTF-8" unless File.exist? file
      expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
      expect(xml).to be_equivalent_to File.read(file, encoding: "UTF-8")
        .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
    end
  end

  it "get 3GPP document" do
    VCR.use_cassette "3gpp_01_01" do
      item = RelatonIetf::IetfBibliography.search "3GPP 01.01"
      expect(item.docidentifier[0].id).to eq "3GPP 01.01"
    end
  end

  it "get IEEE document" do
    VCR.use_cassette "ieee_730_2014" do
      item = RelatonIetf::IetfBibliography.search "IEEE 730_2014"
      expect(item.docidentifier[0].id).to eq "IEEE 730_2014"
    end
  end

  it "get best current practise" do
    VCR.use_cassette "bcp_47" do
      item = RelatonIetf::IetfBibliography.get "BCP 47"
      expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
      file = "spec/examples/bcp_47.xml"
      xml = item.to_xml bibdata: true
      File.write file, xml unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file).sub(
        %r{<fetched>\d{4}-\d{2}-\d{2}</fetched>},
        "<fetched>#{Date.today}</fetched>",
      )
      schema = Jing.new "spec/examples/isobib.rng"
      errors = schema.validate file
      expect(errors).to eq []
    end
  end

  it "get FYI" do
    VCR.use_cassette "fyi_2" do
      item = RelatonIetf::IetfBibliography.get "FYI 2"
      expect(item.docidentifier[0].id).to eq "FYI 2"
    end
  end

  it "get STD" do
    VCR.use_cassette "std_3" do
      item = RelatonIetf::IetfBibliography.get "STD 3"
      expect(item.docidentifier[0].id).to eq "STD 3"
    end
  end

  it "deals with extraneous prefix" do
    VCR.use_cassette "error" do
      expect do
        RelatonIetf::IetfBibliography.get "CN 8341"
      end.to output(/not found/).to_stderr
    end
  end

  it "deals with non-existent document" do
    VCR.use_cassette "non_existed_doc" do
      item = RelatonIetf::IetfBibliography.get "RFC 08341"
      expect(item).to be_nil
    end
  end

  context "create RelatonIetf::IetfBibliographicItem from xml" do
    it "RFC" do
      xml = File.read "spec/examples/bib_item.xml"
      item = RelatonIetf::XMLParser.from_xml xml
      expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
      expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
    end

    it "BCP" do
      xml = File.read "spec/examples/bcp_47.xml"
      item = RelatonIetf::XMLParser.from_xml xml
      expect(item).to be_instance_of RelatonIetf::IetfBibliographicItem
      expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
    end

    it "warn if XML doesn't have bibitem or bibdata element" do
      item = ""
      expect { item = RelatonIetf::XMLParser.from_xml "" }.to output(
        /can't find bibitem/,
      ).to_stderr
      expect(item).to be_nil
    end
  end
end
