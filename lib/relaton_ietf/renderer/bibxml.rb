module RelatonIetf
  module Renderer
    class BibXML < RelatonBib::Renderer::BibXML
      #
      # Render dates as BibXML. Override to skip IANA date rendering.
      #
      # @param [Nokogiri::XML::Builder] builder xml builder
      #
      def render_date(builder)
        super unless @bib.docidentifier.detect { |i| i.type == "IANA" }
      end

      #
      # Render authors as BibXML. Override to skip "RFC Publisher" organization.
      #
      # @param [Nokogiri::XML::Builder] builder xml builder
      #
      def render_authors(builder) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        @bib.contributor.each do |c|
          next if c.entity.is_a?(RelatonBib::Organization) && c.entity.name.map(&:content).include?("RFC Publisher")

          builder.author do |xml|
            xml.parent[:role] = "editor" if c.role.detect { |r| r.type == "editor" }
            if c.entity.is_a?(RelatonBib::Person) then render_person xml, c.entity
            else render_organization xml, c.entity, c.role
            end
            render_address xml, c
          end
        end
      end
    end
  end
end
