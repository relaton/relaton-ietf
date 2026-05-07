require "relaton/ietf/data_fetcher"

RSpec.describe Relaton::Ietf::DataFetcher do
  let(:index) do
    idx = double("index")
    allow(idx).to receive(:add_or_update)
    allow(idx).to receive(:save)
    idx
  end

  before(:each) do
    allow(Relaton::Index).to receive(:find_or_create)
      .with(:IETF, file: "index-v1.yaml").and_return(index)
  end

  # it "fetch rfc index" do
  #   VCR.use_cassette "ietf_rfc_index" do
  #     described_class.fetch "ietf-rfcsubseries", format: "bibxml"
  #   end
  # end

  # it "fetch internet-drafts" do
  #   VCR.use_cassette "ietf_internet_drafts" do
  #     described_class.fetch "ietf-internet-drafts"
  #   end
  # end

  # it "fetch ietf-rfc-entries" do
  #   VCR.use_cassette "ietf_rfc_entries" do
  #     described_class.fetch "ietf-rfc-entries"
  #   end
  # end

  it "create output dir and run fetcher" do
    expect(FileUtils).to receive(:mkdir_p).with("dir")
    fetcher = double("fetcher")
    expect(fetcher).to receive(:fetch).with("source")
    expect(described_class).to receive(:new).with("dir", "xml").and_return(fetcher)
    described_class.fetch "source", output: "dir", format: "xml"
  end

  context "instance ietf-rfcsubseries" do
    subject { described_class.new("dir", "yaml") }

    before do
      xml = File.read "spec/fixtures/ietf_rfcsubseries.xml"
      allow(Net::HTTP).to receive(:get).and_return(xml)
      allow(Relaton::Ietf::WgNameResolver).to receive(:fetch).and_return({})
    end

    it "fetch data" do
      expect(subject).to receive(:save_doc).exactly(11).times
      expect(index).to receive(:save)
      subject.fetch "ietf-rfcsubseries"
    end
  end

  context "instance ietf-internet-drafts" do
    subject { described_class.new("dir", "yaml") }

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "yaml"
      expect(subject.instance_variable_get(:@files)).to be_a Set
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "yaml"
      expect(subject).to be_instance_of(described_class)
    end

    it "fetch data routes through parse_drafts, emit_series, and singletons" do
      series_map = { "draft-x" => [{ ver: "00", bib: :bib_v0, ref: "draft-x-00", source: [] }] }
      singletons = [:singleton_bib]
      expect(subject).to receive(:parse_drafts).and_return([series_map, singletons])
      expect(subject).to receive(:emit_series).with(series_map)
      expect(subject).to receive(:save_doc).with(:singleton_bib)
      expect(index).to receive(:save)
      subject.fetch "ietf-internet-drafts"
    end

    describe "#parse_drafts" do
      it "groups versioned drafts under normalized series stem" do
        paths = [
          "bibxml-ids/reference.I-D.draft-collins-pfr-00.xml",
          "bibxml-ids/reference.I-D.draft-collins-pfr-01.xml",
        ]
        expect(Dir).to receive(:[]).with("bibxml-ids/*.xml").and_return(paths)
        bib0 = double("bib0", source: [:src0])
        bib1 = double("bib1", source: [:src1])
        allow(bib0).to receive(:version=)
        allow(bib1).to receive(:version=)
        allow(Relaton::Bib::Version).to receive(:new).and_return(:ver)
        expect(File).to receive(:read).with(paths[0], encoding: "UTF-8").and_return("xml-0")
        expect(File).to receive(:read).with(paths[1], encoding: "UTF-8").and_return("xml-1")
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with("xml-0").and_return(bib0)
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with("xml-1").and_return(bib1)

        series_map, singletons = subject.send(:parse_drafts)
        expect(singletons).to be_empty
        expect(series_map.keys).to eq ["draft-collins-pfr"]
        expect(series_map["draft-collins-pfr"].map { |e| e[:ver] }).to eq %w[00 01]
        expect(series_map["draft-collins-pfr"].map { |e| e[:bib] }).to eq [bib0, bib1]
      end

      it "normalizes series names containing dots" do
        path = "bibxml-ids/reference.I-D.draft-foo.bar-00.xml"
        expect(Dir).to receive(:[]).with("bibxml-ids/*.xml").and_return([path])
        bib = double("bib", source: nil)
        allow(bib).to receive(:version=)
        allow(Relaton::Bib::Version).to receive(:new).and_return(:ver)
        expect(File).to receive(:read).with(path, encoding: "UTF-8").and_return("xml")
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with("xml").and_return(bib)

        series_map, _singletons = subject.send(:parse_drafts)
        expect(series_map.keys).to eq ["draft-foo-bar"]
      end

      it "puts non-versioned files into singletons" do
        path = "bibxml-ids/reference.I-D.draft-just-a-name.xml"
        expect(Dir).to receive(:[]).with("bibxml-ids/*.xml").and_return([path])
        bib = double("bib", source: nil)
        expect(File).to receive(:read).with(path, encoding: "UTF-8").and_return("xml")
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with("xml").and_return(bib)

        series_map, singletons = subject.send(:parse_drafts)
        expect(series_map).to be_empty
        expect(singletons).to eq [bib]
      end
    end

    describe "#emit_series" do
      it "sorts each series, links neighbors, saves once, and creates the series doc" do
        e0 = { ver: "00", bib: double("bib0"), ref: "draft-x-00", source: [:s] }
        e1 = { ver: "01", bib: double("bib1"), ref: "draft-x-01", source: [:s] }
        series_map = { "draft-x" => [e1, e0] } # intentionally unsorted

        expect(subject).to receive(:link_neighbor_relations) do |sorted|
          expect(sorted.map { |e| e[:ver] }).to eq %w[00 01]
        end
        expect(subject).to receive(:save_doc).with(e0[:bib]).ordered
        expect(subject).to receive(:save_doc).with(e1[:bib]).ordered
        expect(subject).to receive(:create_series) do |series, sorted|
          expect(series).to eq "draft-x"
          expect(sorted.map { |e| e[:ver] }).to eq %w[00 01]
        end
        subject.send(:emit_series, series_map)
      end

      it "skips relation linking and series doc when format is bibxml" do
        bibxml_subject = described_class.new("dir", "bibxml")
        entry = { ver: "00", bib: double("bib"), ref: "draft-x-00", source: [] }
        expect(bibxml_subject).not_to receive(:link_neighbor_relations)
        expect(bibxml_subject).to receive(:save_doc).with(entry[:bib])
        expect(bibxml_subject).not_to receive(:create_series)
        bibxml_subject.send(:emit_series, "draft-x" => [entry])
      end
    end

    describe "#link_neighbor_relations" do
      it "links each entry to its immediate predecessor and successor only" do
        relations = Array.new(3) { [] }
        bibs = relations.map { |r| double("bib", relation: r) }
        sorted = bibs.each_with_index.map do |bib, i|
          { ver: format("%02d", i), bib: bib, ref: "draft-x-#{format('%02d', i)}", source: [] }
        end

        subject.send(:link_neighbor_relations, sorted)

        expect(relations[0].map(&:type)).to eq ["updatedBy"]
        expect(relations[1].map(&:type)).to eq %w[updates updatedBy]
        expect(relations[2].map(&:type)).to eq ["updates"]
      end

      it "no-ops for single-version series" do
        bib = double("bib", relation: [])
        sorted = [{ ver: "00", bib: bib, ref: "draft-x-00", source: [] }]
        subject.send(:link_neighbor_relations, sorted)
        expect(bib.relation).to be_empty
      end
    end

    it "create unversioned doc using in-memory bib (no disk round-trip)" do
      last_v = double("last_v", title: :t, abstract: :a)
      sorted = [
        { ver: "00", bib: double("b0"), ref: "draft-collins-pfr-00", source: [:src1] },
        { ver: "01", bib: last_v, ref: "draft-collins-pfr-01", source: [:src2] },
      ]
      expect(Relaton::Bib::Docidentifier).to receive(:new)
        .with(type: "Internet-Draft", content: "draft-collins-pfr", primary: true).and_return(:id)
      expect(Relaton::Bib::Docidentifier).to receive(:new)
        .with(type: "Internet-Draft", content: "draft-collins-pfr-00", primary: true).and_return(:id1)
      expect(Relaton::Bib::Docidentifier).to receive(:new)
        .with(type: "Internet-Draft", content: "draft-collins-pfr-01", primary: true).and_return(:id2)
      expect(Relaton::Bib::Formattedref).to receive(:new).with(content: "draft-collins-pfr-00").and_return(:fref1)
      expect(Relaton::Bib::Formattedref).to receive(:new).with(content: "draft-collins-pfr-01").and_return(:fref2)
      expect(Relaton::Ietf::ItemData).to receive(:new).with(formattedref: :fref1, docidentifier: [:id1], source: [:src1]).and_return(:bibitem1)
      expect(Relaton::Ietf::ItemData).to receive(:new).with(formattedref: :fref2, docidentifier: [:id2], source: [:src2]).and_return(:bibitem2)
      expect(Relaton::Ietf::Relation).to receive(:new).with(type: "includes", bibitem: :bibitem1).and_return(:rel1)
      expect(Relaton::Ietf::Relation).to receive(:new).with(type: "includes", bibitem: :bibitem2).and_return(:rel2)
      expect(Relaton::Bib::Formattedref).to receive(:new).with(content: "draft-collins-pfr").and_return(:fref3)
      expect(Relaton::Ietf::ItemData).to receive(:new).with(
        title: :t, abstract: :a, formattedref: :fref3, docidentifier: [:id], relation: %i[rel1 rel2],
      ).and_return(:sbib)
      expect(File).not_to receive(:read)
      expect(subject).to receive(:save_doc).with(:sbib)

      subject.send(:create_series, "draft-collins-pfr", sorted)
    end

    it "warns and returns when sorted entries are empty" do
      expect(subject).not_to receive(:save_doc)
      expect { subject.send(:create_series, "draft-x", []) }
        .to output(/No versions found for draft-x/).to_stderr_from_any_process
    end

    it "create version relation" do
      rel = subject.send(:version_relation, { ref: "draft-collins-pfr-00", source: [] }, "includes")
      expect(rel).to be_instance_of(Relaton::Ietf::Relation)
    end
  end

  context "instance ietf-rfc-entries" do
    subject { described_class.new("dir", "bibxml") }

    before do
      xml = File.read "spec/fixtures/ietf_rfcsubseries.xml"
      allow(Net::HTTP).to receive(:get).and_return(xml)
      allow(Relaton::Ietf::WgNameResolver).to receive(:fetch).and_return({})
    end

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "xml"
      expect(subject.instance_variable_get(:@files)).to be_a Set
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "bibxml"
      expect(subject).to be_instance_of(described_class)
    end

    it "fetch data" do
      expect(subject).to receive(:save_doc).with(kind_of(Relaton::Ietf::ItemData)).exactly(2).times
      expect(index).to receive(:save)
      subject.fetch "ietf-rfc-entries"
    end
  end

  context "save doc" do
    subject { described_class.new("dir", "bibxml") }

    let(:entry) do
      did = double("docid", type: "RFC", content: "RFC 1", primary: true)
      double("entry", docnumber: "RFC0001", docidentifier: [did])
    end

    it "skip" do
      expect(File).not_to receive(:write)
      subject.send(:save_doc, nil)
    end

    it "bibxml" do
      expect(entry).to receive(:to_rfcxml).and_return("<xml/>")
      expect(File).to receive(:write).with("dir/rfc0001.xml", "<xml/>", encoding: "UTF-8")
      expect(index).to receive(:add_or_update).with("RFC 1", "dir/rfc0001.xml")
      subject.send(:save_doc, entry)
    end

    it "xml" do
      subject.instance_variable_set(:@format, "xml")
      expect(entry).to receive(:to_xml).with(bibdata: true).and_return("<xml/>")
      expect(File).to receive(:write).with("dir/rfc0001.xml", "<xml/>", encoding: "UTF-8")
      subject.send(:save_doc, entry)
    end

    it "yaml" do
      subject.instance_variable_set(:@format, "yaml")
      subject.instance_variable_set(:@ext, "yaml")
      expect(entry).to receive(:to_yaml).and_return("---\nid: 123\n")
      expect(File).to receive(:write).with("dir/rfc0001.yaml", "---\nid: 123\n", encoding: "UTF-8")
      subject.send(:save_doc, entry)
    end

    it "warn when file exists" do
      subject.instance_variable_set(:@files, Set.new(["dir/rfc0001.xml"]))
      expect(entry).to receive(:to_rfcxml).and_return("<xml/>")
      expect(File).to receive(:write)
        .with("dir/rfc0001.xml", "<xml/>", encoding: "UTF-8")
      expect { subject.send(:save_doc, entry) }
        .to output(/File dir\/rfc0001.xml already exists/).to_stderr_from_any_process
    end

    it "downcase file name for ID" do
      subject.instance_variable_set(:@source, "ietf-internet-drafts")
      docid = [
        Relaton::Bib::Docidentifier.new(type: "Internet-Draft", content: "I-D.3gpp-collaboration"),
        Relaton::Bib::Docidentifier.new(type: "Internet-Draft", content: "I-D.3gpp-collaboration-00", primary: true),
      ]
      id_entry = Relaton::Ietf::ItemData.new(docidentifier: docid)
      expect(id_entry).to receive(:to_rfcxml).and_return("<xml/>")
      expect(File).to receive(:write).with("dir/i-d-3gpp-collaboration-00.xml", "<xml/>", encoding: "UTF-8")
      expect(index).to receive(:add_or_update).with("I-D.3gpp-collaboration-00", "dir/i-d-3gpp-collaboration-00.xml")
      subject.send(:save_doc, id_entry)
    end
  end
end
