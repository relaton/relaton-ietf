# frozen_string_literal: true

module RelatonIetf
  # Scrapper module
  module Scrapper
    extend Scrapper

    IDS = "https://raw.githubusercontent.com/ietf-ribose/relaton-data-ids/main/data/"
    RFC = "https://raw.githubusercontent.com/ietf-ribose/relaton-data-rfcs/main/data/"
    RSS = "https://raw.githubusercontent.com/ietf-ribose/relaton-data-rfcsubseries/main/data/"

    # @param text [String]
    # @param is_relation [TrueClass, FalseClass]
    # @return [RelatonIetf::IetfBibliographicItem]
    def scrape_page(text, is_relation: false)
      # Remove initial "IETF " string if specified
      ref = text.gsub(/^IETF /, "")
      ref.sub!(/(?<=^(?:RFC|BCP|FYI|STD))\s(\d+)/) { $1.rjust 4, "0" }
      rfc_item ref, is_relation
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
           Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError,
           Net::ProtocolError, SocketError
      raise RelatonBib::RequestError, "No document found for #{ref} reference"
    end

    private

    # @param ref [String]
    # @param is_relation [Boolen, nil]
    # @return [RelatonIetf::IetfBibliographicItem]
    def rfc_item(ref, is_relation)
      ghurl = case ref
              when /^RFC/ then RFC
              when /^(?:BCP|FYI|STD)/ then RSS
              when /^I-D/
                ref.sub!(/^I-D\./, "")
                IDS
              else return
              end

      uri = "#{ghurl}#{ref.sub(/\s|\u00a0/, '.')}.yaml"
      # BibXMLParser.parse get_page(uri), is_relation: is_relation, ver: ver
      resp = get_page uri
      IetfBibliographicItem.from_hash YAML.safe_load(resp) if resp
    end

    # @param uri [String]
    # @return [String] HTTP response body
    def get_page(uri)
      res = Net::HTTP.get_response(URI(uri))
      return unless res.code == "200"

      res.body
    end
  end
end
