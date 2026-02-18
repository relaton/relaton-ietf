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

    it "fetch data" do
      expect(Dir).to receive(:[]).with("bibxml-ids/*.xml").and_return(["bibxml-ids/reference.I-D.draft-collins-pfr-00.xml"])
      expect(File).to receive(:read).with("bibxml-ids/reference.I-D.draft-collins-pfr-00.xml", encoding: "UTF-8").and_return(:xml)
      bib = double("bib")
      allow(bib).to receive(:version=)
      allow(bib).to receive(:source).and_return([:src])
      expect(Relaton::Bib::Version).to receive(:new).with(draft: "00").and_return(:ver)
      expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with(:xml).and_return(bib)
      expect(subject).to receive(:save_doc).with(bib)
      expect(subject).to receive(:update_versions).with [{ ref: "draft-collins-pfr-00", source: [:src] }]
      expect(index).to receive(:save)
      subject.fetch "ietf-internet-drafts"
    end

    it "update versions" do
      expect(Dir).to receive(:[]).with("dir/*.yaml").and_return(["dir/draft-collins-pfr-00.yaml"])
      expect(subject).to receive(:create_series).with("draft-collins-pfr", [{ ref: "draft-collins-pfr-01", source: [:src] }])
      relation = double("relation")
      expect(relation).to receive(:<<).with(:relation)
      bib = double("bib", relation: relation)
      expect(subject).to receive(:read_doc).with("dir/draft-collins-pfr-00.yaml").and_return(bib)
      expect(Relaton::Bib::Docidentifier).to receive(:new)
        .with(type: "Internet-Draft", content: "draft-collins-pfr-01", primary: true).and_return(:id)
      expect(Relaton::Ietf::ItemData).to receive(:new).with(formattedref: "draft-collins-pfr-01", docidentifier: [:id], source: [:src]).and_return(:bibitem)
      expect(Relaton::Bib::Relation).to receive(:new).with(type: "updatedBy", bibitem: :bibitem).and_return(:relation)
      expect(subject).to receive(:save_doc).with(bib, check_duplicate: false)
      subject.send(:update_versions, [{ ref: "draft-collins-pfr-01", source: [:src] }, { ref: "draft-collins-pfr1-02", source: [:src] }])
    end

    it "create unversioned doc" do
      expect(Relaton::Bib::Docidentifier).to receive(:new)
        .with(type: "Internet-Draft", content: "draft-collins-pfr", primary: true).and_return(:id)
      expect(Relaton::Bib::Docidentifier).to receive(:new)
        .with(type: "Internet-Draft", content: "draft-collins-pfr-00", primary: true).and_return(:id1)
      expect(Relaton::Bib::Docidentifier).to receive(:new)
        .with(type: "Internet-Draft", content: "draft-collins-pfr-01", primary: true).and_return(:id2)
      expect(Relaton::Ietf::ItemData).to receive(:new).with(formattedref: "draft-collins-pfr-00", docidentifier: [:id1], source: [:src1]).and_return(:bibitem1)
      expect(Relaton::Ietf::ItemData).to receive(:new).with(formattedref: "draft-collins-pfr-01", docidentifier: [:id2], source: [:src2]).and_return(:bibitem2)
      expect(Relaton::Bib::Relation).to receive(:new).with(type: "includes", bibitem: :bibitem1).and_return(:rel1)
      expect(Relaton::Bib::Relation).to receive(:new).with(type: "includes", bibitem: :bibitem2).and_return(:rel2)
      last_v = double("last_v", title: :t, abstract: :a)
      # expect(File).to receive(:exist?).with("dir/draft-collins-pfr-01.yaml").and_return(true)
      expect(File).to receive(:read).with("dir/draft-collins-pfr-01.yaml", encoding: "UTF-8").and_return(:yaml_str)
      expect(Relaton::Ietf::Item).to receive(:from_yaml).with(:yaml_str).and_return(last_v)
      expect(Relaton::Ietf::ItemData).to receive(:new).with(
        title: :t, abstract: :a, formattedref: "draft-collins-pfr", docidentifier: [:id], relation: %i[rel1 rel2],
      ).and_return(:sbib)
      expect(subject).to receive(:save_doc).with(:sbib)
      subject.send(:create_series, "draft-collins-pfr",
                    [{ ref: "draft-collins-pfr-00", source: [:src1] }, { ref: "draft-collins-pfr-01", source: [:src2] }])
    end

    it "create version relation" do
      rel = subject.send(:version_relation, { ref: "draft-collins-pfr-00", source: [] }, "includes")
      expect(rel).to be_instance_of(Relaton::Bib::Relation)
    end
  end

  context "read doc" do
    it "yaml" do
      file = "dir/reference.I-D.draft-collins-pfr-00.yaml"
      fetcher = described_class.new("dir", "yaml")
      expect(File).to receive(:read).with(file, encoding: "UTF-8").and_return(:yaml)
      expect(Relaton::Ietf::Item).to receive(:from_yaml).with(:yaml).and_return(:bib)
      expect(fetcher.send(:read_doc, file)).to be :bib
    end

    it "xml" do
      file = "dir/reference.I-D.draft-collins-pfr-00.xml"
      fetcher = described_class.new("dir", "xml")
      expect(File).to receive(:read).with(file, encoding: "UTF-8").and_return(:xml)
      expect(Relaton::Ietf::Item).to receive(:from_xml).with(:xml).and_return(:bib)
      expect(fetcher.send(:read_doc, file)).to be :bib
    end

    it "bibxml" do
      file = "dir/reference.I-D.draft-collins-pfr-00.xml"
      fetcher = described_class.new("dir", "bibxml")
      expect(File).to receive(:read).with(file, encoding: "UTF-8").and_return(:xml)
      expect(Relaton::Ietf::BibXMLParser).to receive(:parse).with(:xml).and_return(:bib)
      expect(fetcher.send(:read_doc, file)).to be :bib
    end
  end

  context "instance ietf-rfc-entries" do
    subject { described_class.new("dir", "bibxml") }

    before do
      xml = File.read "spec/fixtures/ietf_rfcsubseries.xml"
      allow(Net::HTTP).to receive(:get).and_return(xml)
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
      expect(subject.send(:file_name, id_entry)).to eq "dir/i-d.3gpp-collaboration-00.xml"
    end
  end
end
