RSpec.describe RelatonIetf::IetfBibliographicItem do
  it "warn if doctype is invalid" do
    expect do
      RelatonIetf::IetfBibliographicItem.new doctype: "type"
    end.to output(/invalid doctype type/).to_stderr
  end
end
