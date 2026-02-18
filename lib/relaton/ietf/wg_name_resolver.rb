# frozen_string_literal: true

require "json"
require "net/http"

module Relaton
  module Ietf
    # Fetches working group and research group names from the IETF Datatracker API.
    # Returns a Hash mapping acronym (lowercase) to full group name.
    module WgNameResolver
      API_URL = "https://datatracker.ietf.org/api/v1/group/group/"

      # @return [Hash{String => String}] acronym => full name
      def self.fetch
        result = {}
        offset = 0
        limit = 1000
        loop do
          uri = URI("#{API_URL}?type__in=wg,rg&limit=#{limit}&offset=#{offset}&format=json")
          response = Net::HTTP.get_response(uri)
          break unless response.is_a?(Net::HTTPSuccess)

          data = JSON.parse(response.body)
          objects = data["objects"] || []
          break if objects.empty?

          objects.each do |group|
            acronym = group["acronym"]
            name = group["name"]
            result[acronym] = name if acronym && name
          end
          offset += limit
          break unless data.dig("meta", "next")
        end
        result
      rescue StandardError => e
        Util.warn "Failed to fetch WG names from Datatracker: #{e.message}"
        {}
      end
    end
  end
end
