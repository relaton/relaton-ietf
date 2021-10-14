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

  # it "returns organization" do
  #   doc = Nokogiri::XML <<~END_XML
  #     <reference anchor="RFC8341" target="https://www.rfc-editor.org/info/rfc8341">
  #       <front><title>Network Configuration Access Control Model</title></front>
  #       <seriesinfo stream="Org"/>
  #     </reference>
  #   END_XML
  #   ref = doc.at "/reference"
  #   expect(RelatonIetf::Scrapper.send(:organizations, ref)[0][:entity]).
  #     to be_instance_of RelatonBib::Organization
  # end

  # it "returns default affiliation" do
  #   doc = Nokogiri::XML <<~END_XML
  #     <author fullname="Arthur son of Uther Pendragon" asciiFullname="Arthur son of Uther Pendragon">
  #       <address>
  #         <postal/>
  #         <email>arthur.pendragon@ribose.com</email>
  #         <uri>http://camelot.gov.example</uri>
  #       </address>
  #     </author>"
  #   END_XML
  #   author = doc.at "/author"
  #   expect(RelatonIetf::Scrapper.send(:affiliation, author)).to be_instance_of RelatonBib::Affiliation
  # end

  it "returns status" do
    doc = Nokogiri::XML <<~END_XML
      <reference anchor="RFC8341" target="https://www.rfc-editor.org/info/rfc8341">
        <front><title>Network Configuration Access Control Model</title></front>
        <seriesinfo status="published"/>
      </reference>
    END_XML
    ref = doc.at "//reference"
    expect(RelatonIetf::Scrapper.send(:status, ref)).to be_instance_of RelatonBib::DocumentStatus
  end

  it "return hash" do
    yaml = YAML.load_file "spec/examples/ietf_bib_item.yml"
    hash = RelatonIetf::HashConverter.hash_to_bib yaml
    item = RelatonIetf::IetfBibliographicItem.new(**hash)
    yaml["fetched"] = Date.today.to_s
    expect(item.to_hash).to eq yaml
  end
end
