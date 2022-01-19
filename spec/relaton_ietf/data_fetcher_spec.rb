RSpec.describe RelatonIetf::DataFetcher do
  # it "fetch rfc index" do
  #   VCR.use_cassette "ietf_rfc_index" do
  #     RelatonIetf::DataFetcher.fetch "ietf-rfcsubseries", format: "bibxml"
  #   end
  # end

  # it "fetch internet-drafts" do
  #   VCR.use_cassette "ietf_internet_drafts" do
  #     RelatonIetf::DataFetcher.fetch "ietf-internet-drafts"
  #   end
  # end

  # it "fetch ietf-rfc-entries" do
  #   VCR.use_cassette "ietf_rfc_entries" do
  #     RelatonIetf::DataFetcher.fetch "ietf-rfc-entries"
  #   end
  # end

  it "create output dir and run fetcher" do
    expect(Dir).to receive(:exist?).with("dir").and_return(false)
    expect(FileUtils).to receive(:mkdir_p).with("dir")
    fetcher = double("fetcher")
    expect(fetcher).to receive(:fetch)
    expect(RelatonIetf::DataFetcher)
      .to receive(:new).with("source", "dir", "xml").and_return(fetcher)
    RelatonIetf::DataFetcher.fetch "source", output: "dir", format: "xml"
  end

  context "instance ietf-rfcsubseries" do
    subject { RelatonIetf::DataFetcher.new("ietf-rfcsubseries", "dir", "yaml") }

    before do
      xml = File.read "spec/examples/ietf_rfcsubseries.xml"
      allow(Net::HTTP).to receive(:get).and_return(xml)
    end

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "yaml"
      expect(subject.instance_variable_get(:@files)).to eq []
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "yaml"
      expect(subject.instance_variable_get(:@source)).to eq "ietf-rfcsubseries"
      expect(subject).to be_instance_of(RelatonIetf::DataFetcher)
    end

    it "fetch data" do
      expect(subject).to receive(:save_doc).with(:bib).exactly(11).times
      expect(RelatonIetf::RfcIndexEntry).to receive(:parse)
        .with(kind_of(Nokogiri::XML::Element))
        .and_return(:bib).exactly(11).times
      subject.fetch
    end
  end

  context "instance ietf-internet-drafts" do
    subject { RelatonIetf::DataFetcher.new("ietf-internet-drafts", "dir", "yaml") }

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "yaml"
      expect(subject.instance_variable_get(:@files)).to eq []
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "yaml"
      expect(subject.instance_variable_get(:@source)).to eq "ietf-internet-drafts"
      expect(subject).to be_instance_of(RelatonIetf::DataFetcher)
    end

    it "fetch data" do
      # expect(OpenURI).to receive(:open_uri).with("https://www.ietf.org/lib/dt/sprint/bibxml-ids.tgz").and_return(:gz)
      # gzr = double("gz_reader")
      # expect(gzr).to receive(:read).and_return(:tarh)
      # expect(gzr).to receive(:close)
      # expect(Zlib::GzipReader).to receive(:new).with(:gz).and_return(gzr)
      # expect(StringIO).to receive(:new).with(:tarh).and_return(:io)
      # tarfile1 = double("tarfile1")
      # expect(tarfile1).to receive(:directory?).and_return(true)
      # tarfile2 = double("tarfile2")
      # expect(tarfile2).to receive(:directory?).and_return(false)
      # expect(tarfile2).to receive(:read).and_return(:xml)
      # tar = [tarfile1, tarfile2]
      # expect(Gem::Package::TarReader).to receive(:new).with(:io).and_yield(tar)
      expect(Dir).to receive(:[]).with("bibxml-ids/*.xml").and_return([:file])
      expect(File).to receive(:read).with(:file, encoding: "UTF-8").and_return(:xml)
      expect(RelatonIetf::BibXMLParser).to receive(:parse).with(:xml).and_return(:bib)
      expect(subject).to receive(:save_doc).with(:bib)
      subject.fetch
    end
  end

  context "instance ietf-rfc-entries" do
    subject { RelatonIetf::DataFetcher.new("ietf-rfc-entries", "dir", "bibxml") }

    before do
      xml = File.read "spec/examples/ietf_rfcsubseries.xml"
      allow(Net::HTTP).to receive(:get).and_return(xml)
    end

    it "initialize fetcher" do
      expect(subject.instance_variable_get(:@ext)).to eq "xml"
      expect(subject.instance_variable_get(:@files)).to eq []
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "bibxml"
      expect(subject.instance_variable_get(:@source)).to eq "ietf-rfc-entries"
      expect(subject).to be_instance_of(RelatonIetf::DataFetcher)
    end

    it "fetch data" do
      expect(subject).to receive(:save_doc).with(:bib).exactly(1).times
      expect(RelatonIetf::RfcEntry).to receive(:parse)
        .with(kind_of(Nokogiri::XML::Element))
        .and_return(:bib).exactly(1).times
      subject.fetch
    end
  end

  context "save doc" do
    subject { RelatonIetf::DataFetcher.new("source", "dir", "bibxml") }
    let(:entry) { double("entry", docnumber: "RFC0001", docidentifier: []) }

    it "skip" do
      expect(File).not_to receive(:write)
      subject.save_doc nil
    end

    it "bibxml" do
      expect(entry).to receive(:to_bibxml).and_return("<xml/>")
      expect(File).to receive(:write).with("dir/RFC0001.xml", "<xml/>", encoding: "UTF-8")
      subject.save_doc entry
    end

    it "xml" do
      subject.instance_variable_set(:@format, "xml")
      expect(entry).to receive(:to_xml).with(bibdata: true).and_return("<xml/>")
      expect(File).to receive(:write).with("dir/RFC0001.xml", "<xml/>", encoding: "UTF-8")
      subject.save_doc entry
    end

    it "yaml" do
      subject.instance_variable_set(:@format, "yaml")
      subject.instance_variable_set(:@ext, "yaml")
      expect(entry).to receive(:to_hash).and_return({ id: 123 })
      expect(File).to receive(:write).with("dir/RFC0001.yaml", /id: 123/, encoding: "UTF-8")
      subject.save_doc entry
    end

    it "warn when file exists" do
      subject.instance_variable_set(:@files, ["dir/RFC0001.xml"])
      expect(entry).to receive(:to_bibxml).and_return("<xml/>")
      expect(File).to receive(:write)
        .with("dir/RFC0001.xml", "<xml/>", encoding: "UTF-8")
      expect { subject.save_doc entry }
        .to output(/File dir\/RFC0001.xml already exists/).to_stderr
    end

    it " downcase file name for ID" do
      subject.instance_variable_set(:@source, "ietf-internet-drafts")
      docid = double("docid", type: "Internet-Draft", id: "I-D.3gpp-collaboration")
      id_entry = double("entry", docidentifier: [docid])
      expect(subject.file_name(id_entry)).to eq "dir/i-d.3gpp-collaboration.xml"
    end
  end
end
