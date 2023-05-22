# frozen_string_literal: true

module RelatonIetf
  # Scrapper module
  module Scrapper
    extend Scrapper

    IDS = "https://raw.githubusercontent.com/relaton/relaton-data-ids/main/"
    RFC = "https://raw.githubusercontent.com/relaton/relaton-data-rfcs/main/"
    RSS = "https://raw.githubusercontent.com/relaton/relaton-data-rfcsubseries/main/"
    INDEX_FILE = "index-v1.yaml"

    # @param text [String]
    # @return [RelatonIetf::IetfBibliographicItem]
    def scrape_page(text)
      # Remove initial "IETF " string if specified
      ref = text.gsub(/^IETF /, "")
      # ref.sub!(/(?<=^(?:RFC|BCP|FYI|STD))\s(\d+)/) { $1.rjust 4, "0" }
      rfc_item ref
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
           Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
           Net::ProtocolError, SocketError
      raise RelatonBib::RequestError, "No document found for #{ref} reference"
    end

    private

    # @param ref [String]
    # @return [RelatonIetf::IetfBibliographicItem]
    def rfc_item(ref) # rubocop:disable Metrics/MethodLength
      case ref
      when /^RFC/ then get_rfcs ref
      when /^(?:BCP|FYI|STD)/ then get_rfcsubseries ref
      when /^I-D/
        ref.sub!(/^I-D[.\s]/, "")
        get_ids ref
      end
    end

    def get_rfcs(ref)
      index = Relaton::Index.find_or_create :RFC, url: "#{RFC}index-v1.zip", file: INDEX_FILE
      row = index.search(ref).first
      get_page "#{RFC}#{row[:file]}" if row
    end

    def get_rfcsubseries(ref)
      index = Relaton::Index.find_or_create :RSS, url: "#{RSS}index-v1.zip", file: INDEX_FILE
      row = index.search(ref).first
      get_page "#{RSS}#{row[:file]}" if row
    end

    def get_ids(ref)
      index = Relaton::Index.find_or_create :IDS, url: "#{IDS}index-v1.zip", file: INDEX_FILE
      row = index.search(ref).first
      get_page "#{IDS}#{row[:file]}" if row
    end

    # @param uri [String]
    # @return [RelatonIetf::IetfBibliographicItem, nil] HTTP response body
    def get_page(uri)
      res = Net::HTTP.get_response(URI(uri))
      return unless res.code == "200"

      hash = YAML.safe_load res.body
      hash["fetched"] = Date.today.to_s
      IetfBibliographicItem.from_hash hash
    end
  end
end
