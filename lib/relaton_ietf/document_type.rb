module RelatonIetf
  class DocumentType < RelatonBib::DocumentType
    DOCTYPES = %w[rfc internet-draft].freeze

    def initialize(type:, abbreviation: nil)
      check_type type
      super
    end

    def check_type(type)
      unless DOCTYPES.include? type
        Util.warn "Invalid doctype: `#{type}`"
      end
    end
  end
end
