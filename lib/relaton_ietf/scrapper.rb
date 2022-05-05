# frozen_string_literal: true

module RelatonIetf
  # Scrapper module
  module Scrapper
    extend Scrapper

    GH_URL = "https://raw.githubusercontent.com/relaton/relaton-data-ietf/master/data/reference."

    # @param text [String]
    # @param is_relation [TrueClass, FalseClass]
    # @return [RelatonIetf::IetfBibliographicItem]
    def scrape_page(text, is_relation: false)
      # Remove initial "IETF " string if specified
      ref = text.gsub(/^IETF /, "")
      /^(?:RFC|BCP|FYI|STD)\s(?<num>\d+)/ =~ ref
      ref.sub!(/(?<=^(?:RFC|BCP|FYI|STD)\s)(\d+)/, num.rjust(4, "0")) if num
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
      /(?<=-)(?<ver>\d{2})$/ =~ ref
      if /^I-D/.match? ref
        ref.sub!(/-\d{2}/, "") if ver
        ref.sub!(/(?<=I-D\.)draft-/, "")
      end

      uri = "#{GH_URL}#{ref.sub(/\s|\u00a0/, '.')}.xml"
      # doc = Nokogiri::XML get_page(uri)
      # r = doc.at("/referencegroup", "/reference")
      # fetch_rfc r, is_relation: is_relation, url: uri, ver: ver
      BibXMLParser.parse get_page(uri), is_relation: is_relation, ver: ver
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
