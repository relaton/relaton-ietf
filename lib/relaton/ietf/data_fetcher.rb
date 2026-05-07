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
      # Fetches ietf-internet-drafts documents.
      #
      # Single-pass: parse every BibXML file once into memory, group versioned
      # drafts by their normalized series stem, then emit each draft (with
      # immediate-neighbor updates/updatedBy relations) and the un-versioned
      # series aggregator doc exactly once.
      #
      def fetch_ieft_internet_drafts
        series_map, singletons = parse_drafts
        emit_series(series_map)
        singletons.each { |bib| save_doc bib }
      end

      #
      # Parse all bibxml-ids/*.xml files into memory.
      #
      # @return [Array(Hash, Array)] [series_map, singletons]
      #   series_map: { normalized_series => [{file, ver, bib, ref, source}, ...] }
      #   singletons: bibs that aren't versioned drafts (no `-NN` suffix or no `D.draft-`)
      #
      def parse_drafts # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
        series_map = {}
        singletons = []
        Dir["bibxml-ids/*.xml"].each do |path|
          file = File.basename(path, ".xml")
          is_draft = file.include?("D.draft-")
          ver = is_draft ? file[/(\d+)$/, 1] : nil
          bib = BibXMLParser.parse(File.read(path, encoding: "UTF-8"))
          bib.version = [Bib::Version.new(draft: ver)] if ver

          ref = file.sub(/^reference\.I-D\./, "").downcase
          stem_match = is_draft && ver ? /^(draft-.+)-(\d{2})$/.match(ref) : nil
          if stem_match
            series = stem_match[1].gsub(/[.\s\/:-]+/, "-")
            (series_map[series] ||= []) << { file: file, ver: ver, bib: bib, ref: ref, source: bib.source }
          else
            singletons << bib
          end
        end
        [series_map, singletons]
      end

      #
      # Emit each series: append cross-version relations, save each version doc
      # once, then create the un-versioned aggregator doc. The relation linking
      # and aggregator doc are skipped for bibxml format (matches the legacy
      # `update_versions` skip).
      #
      def emit_series(series_map)
        series_map.each do |series, entries|
          sorted = entries.sort_by { |e| e[:ver].to_i }
          link_neighbor_relations(sorted) if @format != "bibxml"
          sorted.each { |entry| save_doc entry[:bib] }
          create_series(series, sorted) if @format != "bibxml"
        end
      end

      #
      # Append immediate-neighbor `updates` / `updatedBy` relations in memory.
      # Single-version series get no relations (no neighbors).
      #
      def link_neighbor_relations(sorted)
        sorted.each_with_index do |entry, i|
          if i.positive?
            prev = sorted[i - 1]
            entry[:bib].relation << version_relation({ ref: prev[:ref], source: prev[:source] }, "updates")
          end
          if i < sorted.size - 1
            nxt = sorted[i + 1]
            entry[:bib].relation << version_relation({ ref: nxt[:ref], source: nxt[:source] }, "updatedBy")
          end
        end
      end

      #
      # Create the un-versioned series aggregator doc with `includes` relations
      # to every version. Uses the latest version's title/abstract directly
      # from memory (no disk round-trip).
      #
      # @param [String] series normalized series name (e.g. "draft-collins-pfr")
      # @param [Array<Hash>] sorted entries sorted ascending by version
      #
      def create_series(series, sorted)
        if sorted.empty?
          Util.warn "No versions found for #{series}"
          return
        end

        last_v = sorted.last[:bib]
        docid = Bib::Docidentifier.new(type: "Internet-Draft", content: series, primary: true)
        rel = sorted.map { |e| version_relation({ ref: e[:ref], source: e[:source] }, "includes") }
        bib = ItemData.new(
          title: last_v.title, abstract: last_v.abstract, formattedref: Bib::Formattedref.new(content: series),
          docidentifier: [docid], relation: rel
        )
        save_doc bib
      end

      #
      # Create bibitem relation
      #
      # @param [Hash] ver version reference, { ref:, source: }
      # @param [String] type relation type
      #
      # @return [Relaton::Ietf::Relation] relation
      #
      def version_relation(ver, type)
        docid = Bib::Docidentifier.new(type: "Internet-Draft", content: ver[:ref], primary: true)
        bibitem = ItemData.new(formattedref: Bib::Formattedref.new(content: ver[:ref]), docidentifier: [docid], source: ver[:source])
        Relaton::Ietf::Relation.new(type: type, bibitem: bibitem)
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
