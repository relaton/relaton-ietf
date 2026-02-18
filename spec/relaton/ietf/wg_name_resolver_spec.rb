# frozen_string_literal: true

require "relaton/ietf/wg_name_resolver"

RSpec.describe Relaton::Ietf::WgNameResolver do
  let(:api_base) { "https://datatracker.ietf.org/api/v1/group/group/" }

  def stub_api(offset:, body:, status: 200)
    uri = "#{api_base}?type__in=wg,rg&limit=1000&offset=#{offset}&format=json"
    response = instance_double(Net::HTTPSuccess, body: body.to_json, is_a?: true)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(status == 200)
    allow(Net::HTTP).to receive(:get_response)
      .with(URI(uri)).and_return(response)
  end

  it "fetches WG names with single page" do
    stub_api(
      offset: 0,
      body: {
        "meta" => { "next" => nil },
        "objects" => [
          { "acronym" => "ltru", "name" => "Language Tag Registry Update" },
          { "acronym" => "osigen", "name" => "Open Systems Interconnection General" },
        ],
      },
    )
    result = described_class.fetch
    expect(result).to eq(
      "ltru" => "Language Tag Registry Update",
      "osigen" => "Open Systems Interconnection General",
    )
  end

  it "paginates through multiple pages" do
    stub_api(
      offset: 0,
      body: {
        "meta" => { "next" => "/api/v1/group/group/?type__in=wg,rg&limit=1000&offset=1000&format=json" },
        "objects" => [{ "acronym" => "ltru", "name" => "Language Tag Registry Update" }],
      },
    )
    stub_api(
      offset: 1000,
      body: {
        "meta" => { "next" => nil },
        "objects" => [{ "acronym" => "osigen", "name" => "Open Systems Interconnection General" }],
      },
    )
    result = described_class.fetch
    expect(result).to eq(
      "ltru" => "Language Tag Registry Update",
      "osigen" => "Open Systems Interconnection General",
    )
  end

  it "returns empty hash on network error" do
    allow(Net::HTTP).to receive(:get_response).and_raise(SocketError, "connection refused")
    result = nil
    expect { result = described_class.fetch }.to output(/Failed to fetch WG names/).to_stderr_from_any_process
    expect(result).to eq({})
  end

  it "returns empty hash on non-200 response" do
    response = instance_double(Net::HTTPServerError, body: "", is_a?: false)
    allow(response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
    allow(Net::HTTP).to receive(:get_response).and_return(response)
    expect(described_class.fetch).to eq({})
  end
end
