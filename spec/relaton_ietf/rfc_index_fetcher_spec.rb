RSpec.describe RelatonIetf::RfcIndexFetcher do
  it "fetch index" do
    VCR.use_cassette "ietf_rfc_index" do
      RelatonIetf::RfcIndexFetcher.fetch
    end
  end
end
