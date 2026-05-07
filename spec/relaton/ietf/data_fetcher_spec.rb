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

    # Force serial Parallel.map so mocks work and results are deterministic.
    before do
      allow(Parallel).to receive(:map) { |items, **_, &block| items.map(&block) }
    end

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "yaml"
      expect(subject.instance_variable_get(:@files)).to be_a Set
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "yaml"
      expect(subject).to be_instance_of(described_class)
    end

    it "fetch data: groups paths, parallelizes work, records index entries" do
      series_groups = { "draft-x" => [{ path: "p", ver: "00", ref: "draft-x-00" }] }
      singleton_paths = ["bibxml-ids/extra.xml"]
      expect(subject).to receive(:group_draft_paths).and_return([series_groups, singleton_paths])

      series_result = [{ docnumber: "draft-x-00", file: "dir/draft-x-00.yaml", index_id: "draft-x-00" }]
      singleton_result = { docnumber: "extra", file: "dir/extra.yaml", index_id: "extra" }
      expect(subject).to receive(:process_series).with("draft-x", series_groups["draft-x"]).and_return(series_result)
      expect(subject).to receive(:process_singleton).with("bibxml-ids/extra.xml").and_return(singleton_result)
      expect(subject).to receive(:record_index_entry).with(series_result.first)
      expect(subject).to receive(:record_index_entry).with(singleton_result)
      expect(index).to receive(:save)

      subject.fetch "ietf-internet-drafts"
    end

    describe "#group_draft_paths" do
      it "groups versioned drafts under normalized series stem (no XML parsed)" do
        paths = [
          "bibxml-ids/reference.I-D.draft-collins-pfr-00.xml",
          "bibxml-ids/reference.I-D.draft-collins-pfr-01.xml",
        ]
        expect(Dir).to receive(:[]).with("bibxml-ids/*.xml").and_return(paths)
        expect(File).not_to receive(:read)
        expect(Relaton::Ietf::BibXMLParser).not_to receive(:parse)

        series_groups, singletons = subject.send(:group_draft_paths)
        expect(singletons).to be_empty
        expect(series_groups.keys).to eq ["draft-collins-pfr"]
        expect(series_groups["draft-collins-pfr"].map { |e| e[:ver] }).to eq %w[00 01]
        expect(series_groups["draft-collins-pfr"].map { |e| e[:path] }).to eq paths
      end

      it "normalizes series names containing dots" do
        path = "bibxml-ids/reference.I-D.draft-foo.bar-00.xml"
        expect(Dir).to receive(:[]).with("bibxml-ids/*.xml").and_return([path])

        series_groups, _ = subject.send(:group_draft_paths)
        expect(series_groups.keys).to eq ["draft-foo-bar"]
      end

      it "puts non-versioned files into singleton paths" do
        path = "bibxml-ids/reference.I-D.draft-just-a-name.xml"
        expect(Dir).to receive(:[]).with("bibxml-ids/*.xml").and_return([path])

        series_groups, singletons = subject.send(:group_draft_paths)
        expect(series_groups).to be_empty
        expect(singletons).to eq [path]
      end
    end

    describe "#process_series" do
      it "parses, sorts, links neighbors, serializes, returns index entries" do
        paths_info = [
          { path: "p1", ver: "01", ref: "draft-x-01" },
          { path: "p0", ver: "00", ref: "draft-x-00" }, # intentionally unsorted
        ]
        bib0 = double("bib0", source: [:s0])
        bib1 = double("bib1", source: [:s1])
        allow(bib0).to receive(:version=)
        allow(bib1).to receive(:version=)
        allow(Relaton::Bib::Version).to receive(:new).and_return(:ver)
        expect(File).to receive(:read).with("p0", encoding: "UTF-8").and_return("x0")
        expect(File).to receive(:read).with("p1", encoding: "UTF-8").and_return("x1")
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with("x0").and_return(bib0)
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with("x1").and_return(bib1)

        expect(subject).to receive(:link_neighbor_relations) do |sorted|
          expect(sorted.map { |e| e[:ver] }).to eq %w[00 01]
        end
        expect(subject).to receive(:serialize_and_write).with(bib0).and_return(:r0).ordered
        expect(subject).to receive(:serialize_and_write).with(bib1).and_return(:r1).ordered
        expect(subject).to receive(:build_unversioned_doc) do |series, sorted|
          expect(series).to eq "draft-x"
          expect(sorted.map { |e| e[:ver] }).to eq %w[00 01]
          :unversioned
        end
        expect(subject).to receive(:serialize_and_write).with(:unversioned).and_return(:r2)

        results = subject.send(:process_series, "draft-x", paths_info)
        expect(results).to eq %i[r0 r1 r2]
      end

      it "skips relation linking and un-versioned doc when format is bibxml" do
        bibxml_subject = described_class.new("dir", "bibxml")
        bib = double("bib", source: [])
        allow(bib).to receive(:version=)
        allow(Relaton::Bib::Version).to receive(:new).and_return(:ver)
        expect(File).to receive(:read).and_return("x")
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).and_return(bib)
        expect(bibxml_subject).not_to receive(:link_neighbor_relations)
        expect(bibxml_subject).not_to receive(:build_unversioned_doc)
        expect(bibxml_subject).to receive(:serialize_and_write).with(bib).and_return(:r)

        results = bibxml_subject.send(:process_series, "draft-x", [{ path: "p", ver: "00", ref: "draft-x-00" }])
        expect(results).to eq [:r]
      end

      it "drops nil serialize results from build_unversioned_doc" do
        # build_unversioned_doc returns nil for empty sorted, but process_series
        # always feeds it sorted entries. This guards the .compact on results.
        bib = double("bib", source: [])
        allow(bib).to receive(:version=)
        allow(Relaton::Bib::Version).to receive(:new).and_return(:ver)
        expect(File).to receive(:read).and_return("x")
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).and_return(bib)
        allow(subject).to receive(:link_neighbor_relations)
        expect(subject).to receive(:serialize_and_write).with(bib).and_return(:r0)
        allow(subject).to receive(:build_unversioned_doc).and_return(nil)
        expect(subject).to receive(:serialize_and_write).with(nil).and_return(nil)

        results = subject.send(:process_series, "draft-x", [{ path: "p", ver: "00", ref: "draft-x-00" }])
        expect(results).to eq [:r0]
      end
    end

    describe "#process_singleton" do
      it "parses, sets version when present, serializes, returns one result" do
        path = "bibxml-ids/reference.I-D.draft-foo-02.xml"
        bib = double("bib")
        allow(bib).to receive(:version=)
        allow(Relaton::Bib::Version).to receive(:new).with(draft: "02").and_return(:ver)
        expect(File).to receive(:read).with(path, encoding: "UTF-8").and_return("xml")
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with("xml").and_return(bib)
        expect(subject).to receive(:serialize_and_write).with(bib).and_return(:result)

        expect(subject.send(:process_singleton, path)).to eq :result
      end

      it "leaves bib.version untouched for non-D.draft files" do
        path = "bibxml-ids/reference.something-else.xml"
        bib = double("bib")
        expect(bib).not_to receive(:version=)
        expect(File).to receive(:read).and_return("xml")
        expect(Relaton::Ietf::BibXMLParser).to receive(:parse).and_return(bib)
        expect(subject).to receive(:serialize_and_write).with(bib).and_return(:result)

        subject.send(:process_singleton, path)
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

    it "build_unversioned_doc uses in-memory bib (no disk round-trip)" do
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

      expect(subject.send(:build_unversioned_doc, "draft-collins-pfr", sorted)).to eq :sbib
    end

    it "build_unversioned_doc warns and returns nil when sorted is empty" do
      expect { expect(subject.send(:build_unversioned_doc, "draft-x", [])).to be_nil }
        .to output(/No versions found for draft-x/).to_stderr_from_any_process
    end

    describe "#record_index_entry" do
      it "tracks the file in @files and updates the index" do
        result = { docnumber: "n", file: "dir/x.yaml", index_id: "X" }
        expect(index).to receive(:add_or_update).with("X", "dir/x.yaml")
        subject.send(:record_index_entry, result)
        expect(subject.instance_variable_get(:@files)).to include("dir/x.yaml")
      end

      it "warns when @files already contains the same file" do
        subject.instance_variable_set(:@files, Set.new(["dir/x.yaml"]))
        result = { docnumber: "n", file: "dir/x.yaml", index_id: "X" }
        expect(index).to receive(:add_or_update).with("X", "dir/x.yaml")
        expect { subject.send(:record_index_entry, result) }
          .to output(/File dir\/x.yaml already exists/).to_stderr_from_any_process
      end
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
