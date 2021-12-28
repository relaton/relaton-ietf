RSpec.describe RelatonIetf::Scrapper do
  context "raise network error" do
    it "Timeout::Error" do
      expect(Net::HTTP).to receive(:get_response).and_raise Timeout::Error
      expect do
        RelatonIetf::Scrapper.scrape_page "RFC.001"
      end.to raise_error RelatonBib::RequestError
    end

    it "SocketError" do
      expect(Net::HTTP).to receive(:get_response).and_raise SocketError
      expect do
        RelatonIetf::Scrapper.scrape_page "RFC.001"
      end.to raise_error RelatonBib::RequestError
    end
  end

  it "return hash" do
    yaml = YAML.load_file "spec/examples/ietf_bib_item.yml"
    hash = RelatonIetf::HashConverter.hash_to_bib yaml
    item = RelatonIetf::IetfBibliographicItem.new(**hash)
    yaml["fetched"] = Date.today.to_s
    expect(item.to_hash).to eq yaml
  end
end
