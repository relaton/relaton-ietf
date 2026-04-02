require "relaton/core"
require_relative "../ietf"
require_relative "bibxml_parser"
require_relative "rfc/index"
require_relative "rfc/entry"
require_relative "wg_name_resolver"

module Relaton
  module Ietf
    class DataFetcher < Core::DataFetcher
      #
      # Fetch documents
      #
      def fetch(source)
        @source = source
        case source
        when "ietf-rfcsubseries" then fetch_ieft_rfcsubseries
        when "ietf-internet-drafts" then fetch_ieft_internet_drafts
        when "ietf-rfc-entries" then fetch_ieft_rfcs
        end
        index.save
      end

      private

      def index
        @index ||= Relaton::Index.find_or_create :IETF, file: "#{INDEXFILE}.yaml"
      end

      #
      # Fetches ietf-rfcsubseries documents
      #
      def fetch_ieft_rfcsubseries
        idx = Rfc::Index.from_xml(rfc_index)
        rfc_map = (idx.rfc_entries || []).each_with_object({}) do |entry, h|
          h[entry.doc_id] = entry
        end
        idx.subseries_entries.each do |entry|
          save_doc entry.to_item(rfc_map, wg_names: wg_names)
        end
      end

      #
      # Fetches ietf-internet-drafts documents
      #
      def fetch_ieft_internet_drafts # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        versions = Dir["bibxml-ids/*.xml"].each_with_object([]) do |path, vers|
          file = File.basename path, ".xml"
          draft = file.include?("D.draft-")
          /(?<ver>\d+)$/ =~ file if draft
          bib = BibXMLParser.parse(File.read(path, encoding: "UTF-8"))
          if ver
            version = Bib::Version.new(draft: ver)
            bib.version = [version]
          end
          if draft
            vers << { ref: file.sub(/^reference\.I-D\./, "").downcase, source: bib.source }
          end
          save_doc bib
        end
        update_versions(versions) if versions.any? && @format != "bibxml"
      end

      #
      # Updates I-D's versions
      #
      # @param [Array<String>] versions list of versions
      #
      def update_versions(versions) # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        series = ""
        bib_versions = []
        Dir["#{@output}/*.#{@ext}"].each do |file|
          match = /(?<series>draft-.+)-(?<ver>\d{2})\.#{@ext}$/.match file
          if match
            if series != match[:series]
              bib_versions = versions.select { |v| v[:ref].downcase.gsub(/[.\s\/:-]+/, "-").match?(/^#{Regexp.quote match[:series]}-\d{2}/) }
              create_series match[:series], bib_versions
              series = match[:series]
            end
            lv = bib_versions.select { |v| v[:ref].match(/\d+$/).to_s.to_i < match[:ver].to_i }
            hv = bib_versions.select { |v| v[:ref].match(/\d+$/).to_s.to_i > match[:ver].to_i }
            if lv.any? || hv.any?
              bib = read_doc(file)
              bib.relation << version_relation(lv.last, "updates") if lv.any?
              bib.relation << version_relation(hv.first, "updatedBy") if hv.any?
              save_doc bib, check_duplicate: false
            end
          end
        end
      end

      #
      # Create unversioned bibliographic item
      #
      # @param [String] ref reference
      # @param [Array<String>] versions list of versions
      #
      def create_series(ref, versions) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        vs = versions.sort_by { |v| v[:ref].match(/\d+$/).to_s.to_i }
        if vs.empty?
          Util.warn "No versions found for #{ref}"
          return
        end
        file = output_file(vs.last[:ref])
        # return unless File.exist?(file)

        docid = Bib::Docidentifier.new(type: "Internet-Draft", content: ref, primary: true)
        rel = vs.map { |v| version_relation v, "includes" }
        last_v = Item.from_yaml(File.read(file, encoding: "UTF-8"))
        bib = ItemData.new(
          title: last_v.title, abstract: last_v.abstract, formattedref: Bib::Formattedref.new(content: ref),
          docidentifier: [docid], relation: rel
        )
        save_doc bib
      end

      #
      # Create bibitem relation
      #
      # @param [String] ref reference
      # @param [String] type relation type
      #
      # @return [Relaton::Bib::Relation] relation
      #
      def version_relation(ver, type)
        docid = Bib::Docidentifier.new(type: "Internet-Draft", content: ver[:ref], primary: true)
        bibitem = ItemData.new(formattedref: Bib::Formattedref.new(content: ver[:ref]), docidentifier: [docid], source: ver[:source])
        Bib::Relation.new(type: type, bibitem: bibitem)
      end

      #
      # Redad saved documents
      #
      # @param [String] file path to file
      #
      # @return [Relaton::Ietf::ItemData] bibliographic item
      #
      def read_doc(file)
        doc = File.read(file, encoding: "UTF-8")
        case @format
        when "xml" then Item.from_xml(doc)
        when "yaml" then Item.from_yaml(doc)
        else BibXMLParser.parse(doc)
        end
      end

      #
      # Fetches ietf-rfc-entries documents
      #
      def fetch_ieft_rfcs
        idx = Rfc::Index.from_xml(rfc_index)
        idx.rfc_entries.each do |entry|
          save_doc entry.to_item(nil, wg_names: wg_names)
        rescue StandardError => e
          Util.error "Error parsing #{entry.doc_id}: #{e.message}\n" \
            "#{e.backtrace[0..5].join("\n")}"
        end
      end

      #
      # Get RFC index
      #
      # @return [Nokogiri::XML::Document] RFC index
      #
      def rfc_index
        uri = URI "https://www.rfc-editor.org/rfc-index.xml"
        Net::HTTP.get(uri)
      end

      def wg_names
        @wg_names ||= WgNameResolver.fetch
      end

      #
      # Save document to file
      #
      # @param [Relaton::Ietf::Rfc::Entry, nil] rfc index entry
      # @param [Boolean] check_duplicate check for duplicate
      #
      def save_doc(entry, check_duplicate: true) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
        return unless entry

        c = case @format
            when "xml" then entry.to_xml(bibdata: true)
            when "yaml" then entry.to_yaml
            when "bibxml" then entry.to_rfcxml
            else entry.send("to_#{@format}")
            end
        id = if entry.respond_to?(:docidentifier)
               entry.docidentifier.detect { |i| i.type == "Internet-Draft" && i.primary }&.content
             end
        id ||= entry.docnumber || entry.formattedref.content
        file = output_file(id)
        if check_duplicate && @files.include?(file)
          Util.warn "File #{file} already exists. Document: #{entry.docnumber}"
        elsif check_duplicate
          @files << file
        end
        File.write file, c, encoding: "UTF-8"
        add_to_index entry, file
      end

      def add_to_index(entry, file)
        docid = entry.docidentifier.detect(&:primary)
        docid ||= entry.docidentifier.first
        index.add_or_update docid.content, file
      end

    end
  end
end
