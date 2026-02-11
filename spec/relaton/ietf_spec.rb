# frozen_string_literal: true

RSpec.describe Relaton::Ietf do
  it "has a version number" do
    expect(Relaton::Ietf::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = described_class.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  context "get RFC document" do
    it "RFC 8341" do
      VCR.use_cassette "rfc_8341" do
        item = Relaton::Ietf::Bibliography.search "RFC 8341"
        expect(item).to be_instance_of Relaton::Ietf::ItemData
        file = "spec/examples/bib_item.xml"
        xml = item.to_xml(bibdata: true)
        File.write file, xml, encoding: "utf-8" unless File.exist? file
        expect(xml).to be_equivalent_to File.read(file, encoding: "utf-8")
          .sub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
        schema = Jing.new "grammars/relaton-ietf-compile.rng"
        errors = schema.validate file
        expect(errors).to eq []
      end
    end
  end

  it "get internet draft document" do
    VCR.use_cassette "i_d_burger_xcon_mmodels" do
      item = Relaton::Ietf::Bibliography.search "I-D.draft-burger-xcon-mmodels-00"
      expect(item).to be_instance_of Relaton::Ietf::ItemData
      file = "spec/examples/i_d_bib_item.xml"
      xml = item.to_xml(bibdata: true)
      File.write file, xml unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file)
        .sub(%r{(?<=<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
      schema = Jing.new "grammars/relaton-ietf-compile.rng"
      errors = schema.validate file
      expect(errors).to eq []
    end
  end

  it "get internet draft document with version" do
    VCR.use_cassette "i_d_abarth_cake_01" do
      item = Relaton::Ietf::Bibliography.get "I-D draft-abarth-cake-01"
      expect(item.docidentifier.detect { |di| di.type == "Internet-Draft" }.id)
        .to eq "draft-abarth-cake-01"
      expect(item.link.detect { |l| l.type == "src" }.content.to_s).to eq(
        "https://datatracker.ietf.org/doc/html/draft-abarth-cake-01",
      )
    end
  end

  it "get internet draft document by I-D.draft-* reference" do
    VCR.use_cassette "i_d_draft_ietf_calext_eventpub_extensions" do
      item = Relaton::Ietf::Bibliography.get(
        "I-D.draft-ietf-calext-eventpub-extensions-15",
      )
      expect(item.docidentifier.detect { |di| di.type == "Internet-Draft" }.id)
        .to eq("draft-ietf-calext-eventpub-extensions-15")
    end
  end

  it "get best current practise" do
    VCR.use_cassette "bcp_47" do
      item = Relaton::Ietf::Bibliography.get "BCP 47"
      expect(item).to be_instance_of Relaton::Ietf::ItemData
      file = "spec/examples/bcp_47.xml"
      xml = item.to_xml(bibdata: true)
      File.write file, xml unless File.exist? file
      expect(xml).to be_equivalent_to File.read(file)
        .sub(%r{(?<+<fetched>)\d{4}-\d{2}-\d{2}}, Date.today.to_s)
      schema = Jing.new "grammars/relaton-ietf-compile.rng"
      errors = schema.validate file
      expect(errors).to eq []
    end
  end

  it "get FYI", vcr: "fyi_2" do
    expect do
      item = Relaton::Ietf::Bibliography.get "FYI 2"
      expect(item.docidentifier[0].id).to eq "FYI 2"
    end.to output(
      /\[relaton-ietf\] INFO: \(FYI 2\) Fetching from Relaton repository \.\.\./
    ).to_stderr_from_any_process
  end

  it "get STD" do
    VCR.use_cassette "std_3" do
      item = Relaton::Ietf::Bibliography.get "STD 3"
      expect(item.docidentifier[0].id).to eq "STD 3"
    end
  end

  it "deals with extraneous prefix" do
    VCR.use_cassette "error" do
      expect do
        Relaton::Ietf::Bibliography.get "CN 8341"
      end.to output(/Not found\./).to_stderr_from_any_process
    end
  end

  it "deals with non-existent document" do
    VCR.use_cassette "non_existed_doc" do
      item = Relaton::Ietf::Bibliography.get "RFC 0"
      expect(item).to be_nil
    end
  end

  context "create RelatonIetf::IetfBibliographicItem from xml" do
    xit "RFC" do
      xml = File.read "spec/examples/bib_item.xml"
      item = Relaton::Ietf::XMLParser.from_xml xml
      expect(item).to be_instance_of Relaton::Ietf::ItemData
      expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
    end

    xit "BCP" do
      xml = File.read "spec/examples/bcp_47.xml"
      item = Relaton::Ietf::XMLParser.from_xml xml
      expect(item).to be_instance_of Relaton::Ietf::ItemData
      expect(item.to_xml(bibdata: true)).to be_equivalent_to xml
    end

    # it "warn if XML doesn't have bibitem or bibdata element" do
    #   item = ""
    #   expect { item = RelatonIetf::XMLParser.from_xml "" }.to output(
    #     /\[relaton-bib\] WARN: Can't find bibitem or bibdata element in the XML/,
    #   ).to_stderr
    #   expect(item).to be_nil
    # end
  end
end
