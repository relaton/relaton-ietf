# frozen_string_literal: true

module Relaton
  module Ietf
    # Scraper module
    module Scraper
      extend Scraper

      IDS = "https://raw.githubusercontent.com/relaton/relaton-data-ids/refs/heads/data-v2/"
      RFC = "https://raw.githubusercontent.com/relaton/relaton-data-rfcs/refs/heads/data-v2/"
      RSS = "https://raw.githubusercontent.com/relaton/relaton-data-rfcsubseries/refs/heads/data-v2/"

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
        raise Relaton::RequestError, "No document found for #{ref} reference"
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
        index = Relaton::Index.find_or_create :RFC, url: "#{RFC}#{INDEXFILE}.zip", file: "#{INDEXFILE}.yaml"
        row = index.search(ref).first
        get_page "#{RFC}#{row[:file]}" if row
      end

      def get_rfcsubseries(ref)
        index = Relaton::Index.find_or_create :RSS, url: "#{RSS}#{INDEXFILE}.zip", file: "#{INDEXFILE}.yaml"
        row = index.search(ref).first
        get_page "#{RSS}#{row[:file]}" if row
      end

      def get_ids(ref)
        index = Relaton::Index.find_or_create :IDS, url: "#{IDS}#{INDEXFILE}.zip", file: "#{INDEXFILE}.yaml"
        row = index.search(ref).first
        get_page "#{IDS}#{row[:file]}" if row
      end

      # @param uri [String]
      # @return [RelatonIetf::IetfBibliographicItem, nil] HTTP response body
      def get_page(uri)
        res = Net::HTTP.get_response(URI(uri))
        return unless res.code == "200"

        Item.from_yaml(res.body).tap { |item| item.fetched = Date.today.to_s }
      end
    end
  end
end
