require "etc"
require "parallel"
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
      # Each work unit (one series, or one singleton XML) is processed
      # end-to-end in a worker process: parse → link relations → serialize →
      # write. Workers return Marshal-friendly index entries; the parent
      # collects them and updates `Relaton::Index` and the duplicate-check set
      # serially. Set `RELATON_IETF_PARALLEL_WORKERS=0` to force serial
      # execution (useful for tests and debugging).
      #
      def fetch_ieft_internet_drafts
        series_groups, singleton_paths = group_draft_paths

        series_results = parallelize(series_groups.to_a) do |(series, paths_info)|
          process_series(series, paths_info)
        end.flatten(1)

        singleton_results = parallelize(singleton_paths) do |path|
          process_singleton(path)
        end

        (series_results + singleton_results).compact.each { |r| record_index_entry(r) }
      end

      #
      # Run `block` once per item, in parallel worker processes when configured.
      # `Parallel.map(items, in_processes: 0)` runs synchronously in the
      # current process, which keeps tests deterministic and lets mocks work.
      #
      def parallelize(items, &block)
        Parallel.map(items, in_processes: worker_count, &block)
      end

      def worker_count
        ENV.fetch("RELATON_IETF_PARALLEL_WORKERS", Etc.nprocessors.to_s).to_i
      end

      #
      # Filename-only scan: group versioned drafts by normalized series stem;
      # everything else (non-versioned, non-`D.draft-`) goes to singletons.
      # No XML parsing happens here — workers do that.
      #
      # @return [Array(Hash, Array<String>)]
      #   series_groups: { normalized_series => [{path, ver, ref}, ...] }
      #   singleton_paths: [path, ...]
      #
      def group_draft_paths
        series_groups = {}
        singleton_paths = []
        Dir["bibxml-ids/*.xml"].each do |path|
          file = File.basename(path, ".xml")
          is_draft = file.include?("D.draft-")
          ver = is_draft ? file[/(\d+)$/, 1] : nil
          ref = file.sub(/^reference\.I-D\./, "").downcase
          stem_match = is_draft && ver ? /^(draft-.+)-(\d{2})$/.match(ref) : nil
          if stem_match
            series = stem_match[1].gsub(/[.\s\/:-]+/, "-")
            (series_groups[series] ||= []) << { path: path, ver: ver, ref: ref }
          else
            singleton_paths << path
          end
        end
        [series_groups, singleton_paths]
      end

      #
      # Worker: parse all files in a series, sort by version, append
      # immediate-neighbor relations (skipped for bibxml), write each version
      # and the un-versioned aggregator doc. Returns an array of index entries
      # for the parent.
      #
      def process_series(series, paths_info)
        sorted = paths_info.sort_by { |p| p[:ver].to_i }.map do |p|
          bib = BibXMLParser.parse(File.read(p[:path], encoding: "UTF-8"))
          bib.version = [Bib::Version.new(draft: p[:ver])]
          p.merge(bib: bib, source: bib.source)
        end
        link_neighbor_relations(sorted) if @format != "bibxml"

        results = sorted.map { |entry| serialize_and_write(entry[:bib]) }
        results << serialize_and_write(build_unversioned_doc(series, sorted)) if @format != "bibxml"
        results.compact
      end

      #
      # Worker: parse + serialize + write a single non-grouped XML.
      #
      def process_singleton(path)
        file = File.basename(path, ".xml")
        is_draft = file.include?("D.draft-")
        ver = is_draft ? file[/(\d+)$/, 1] : nil
        bib = BibXMLParser.parse(File.read(path, encoding: "UTF-8"))
        bib.version = [Bib::Version.new(draft: ver)] if ver
        serialize_and_write(bib)
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
      # Build (but do not write) the un-versioned series aggregator doc with
      # `includes` relations to every version. Uses the latest version's
      # title/abstract from memory.
      #
      # @return [Relaton::Ietf::ItemData, nil]
      #
      def build_unversioned_doc(series, sorted)
        if sorted.empty?
          Util.warn "No versions found for #{series}"
          return nil
        end

        last_v = sorted.last[:bib]
        docid = Bib::Docidentifier.new(type: "Internet-Draft", content: series, primary: true)
        rel = sorted.map { |e| version_relation({ ref: e[:ref], source: e[:source] }, "includes") }
        ItemData.new(
          title: last_v.title, abstract: last_v.abstract, formattedref: Bib::Formattedref.new(content: series),
          docidentifier: [docid], relation: rel
        )
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
      # Save document to file (sequential path: serialize, write, index).
      # Used by the rfcsubseries / rfc-entries fetchers; the I-D fetcher splits
      # this into worker-safe `serialize_and_write` plus parent-only
      # `record_index_entry` so the index is touched only in the main process.
      #
      # @param [Relaton::Ietf::Rfc::Entry, nil] entry
      # @param [Boolean] check_duplicate check for duplicate
      #
      def save_doc(entry, check_duplicate: true)
        result = serialize_and_write(entry)
        record_index_entry(result, check_duplicate: check_duplicate) if result
      end

      #
      # Worker-safe: serialize, compute output filename, write to disk, return
      # a Marshal-friendly hash with the docid+file pair the parent needs to
      # update `Relaton::Index` and `@files`. Does NOT touch instance state
      # that has to stay consistent across workers (`@files`, the index).
      #
      # @param [#to_yaml, #to_xml, #to_rfcxml, nil] entry
      # @return [Hash, nil]
      #
      def serialize_and_write(entry) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
        return nil unless entry

        content = case @format
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
        File.write file, content, encoding: "UTF-8"
        primary = entry.docidentifier.detect(&:primary) || entry.docidentifier.first
        { docnumber: entry.docnumber, file: file, index_id: primary.content }
      end

      #
      # Parent-only: dedupe-check `@files` and update `Relaton::Index`. Called
      # serially after workers return so index updates are race-free.
      #
      def record_index_entry(result, check_duplicate: true)
        if check_duplicate && @files.include?(result[:file])
          Util.warn "File #{result[:file]} already exists. Document: #{result[:docnumber]}"
        elsif check_duplicate
          @files << result[:file]
        end
        index.add_or_update result[:index_id], result[:file]
      end

    end
  end
end
