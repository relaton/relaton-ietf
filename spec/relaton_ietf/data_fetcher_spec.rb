RSpec.describe RelatonIetf::DataFetcher do
  # it "fetch index" do
  #   VCR.use_cassette "ietf_rfc_index" do
  #     RelatonIetf::RfcIndexFetcher.fetch
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
      expect(subject.instance_variable_get(:@ext)).to eq "xml"
      expect(subject.instance_variable_get(:@files)).to eq []
      expect(subject.instance_variable_get(:@output)).to eq "dir"
      expect(subject.instance_variable_get(:@format)).to eq "xml"
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

  context "save doc" do
    subject { RelatonIetf::DataFetcher.new("source", "dir", "bibxml") }

    it "skip" do
      expect(File).not_to receive(:write)
      subject.save_doc nil
    end

    it "bibxml" do
      entry = double("entry", docnumber: "RFC0001")
      expect(entry).to receive(:to_bibxml).and_return("<xml/>")
      expect(File).to receive(:write).with("dir/RFC0001.xml", "<xml/>", encoding: "UTF-8")
      subject.save_doc entry
    end

    it "xml" do
      subject.instance_variable_set(:@format, "xml")
      entry = double("entry", docnumber: "RFC0001")
      expect(entry).to receive(:to_xml).with(bibdata: true).and_return("<xml/>")
      expect(File).to receive(:write).with("dir/RFC0001.xml", "<xml/>", encoding: "UTF-8")
      subject.save_doc entry
    end

    it "yaml" do
      subject.instance_variable_set(:@format, "yaml")
      subject.instance_variable_set(:@ext, "yaml")
      entry = double("entry", docnumber: "rfc0001")
      expect(entry).to receive(:to_hash).and_return({ id: 123 })
      expect(File).to receive(:write).with("dir/RFC0001.yaml", /id: 123/, encoding: "UTF-8")
      subject.save_doc entry
    end

    it "warn when file exists" do
      subject.instance_variable_set(:@files, ["dir/RFC0001.xml"])
      entry = double("bib", docnumber: "rfc0001")
      expect(entry).to receive(:to_bibxml).and_return("<xml/>")
      expect(File).to receive(:write)
        .with("dir/RFC0001.xml", "<xml/>", encoding: "UTF-8")
      expect { subject.save_doc entry }
        .to output(/File dir\/RFC0001.xml already exists/).to_stderr
    end
  end
end
