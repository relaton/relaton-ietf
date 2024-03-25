describe RelatonIetf::DocumentType do
  it "warn if doctype is invalid" do
    expect do
      described_class.new type: "type"
    end.to output(/\[relaton-ietf\] WARN: Invalid doctype: `type`/).to_stderr_from_any_process
  end
end
