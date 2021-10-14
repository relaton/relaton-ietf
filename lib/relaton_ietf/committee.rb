module RelatonIetf
  class Committee < RelatonBib::TechnicalCommittee
    # @param builder [Nokogiri::XML::Builder]
    def to_xml(builder)
      builder.committee { |b| workgroup.to_xml b }
    end
  end
end
