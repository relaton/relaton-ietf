# require "rubygems"
# require "rubygems/package"
# require "zlib"
require "relaton_ietf/rfc_index_entry"
require "relaton_ietf/rfc_entry"

module RelatonIetf
  class DataFetcher
    INDEX1 = "index-v1".freeze
    #
    # Data fetcher initializer
    #
    # @param [String] source source name
    # @param [String] output directory to save files
    # @param [String] format format of output files (xml, yaml, bibxml);
    #   for ietf-rfcsubseries source only: xml
    #
    def initialize(source, output, format)
      @source = source
      @output = output
      @format = format
      @ext = @format.sub(/^bib|^rfc/, "")
      @files = []
      @index = Relaton::Index.find_or_create :IETF, file: "#{INDEX1}.yaml"
    end

    #
    # Initialize fetcher and run fetch
    #
    # @param [String] source source name
    # @param [Strin] output directory to save files, default: "data"
    # @param [Strin] format format of output files (xml, yaml, bibxml);
    #   default: yaml; for ietf-rfcsubseries source only: xml
    #
    def self.fetch(source, output: "data", format: "yaml")
      t1 = Time.now
      puts "Started at: #{t1}"
      FileUtils.mkdir_p output # unless Dir.exist? output
      new(source, output, format).fetch
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end

    #
    # Fetch documents
    #
    def fetch
      case @source
      when "ietf-rfcsubseries" then fetch_ieft_rfcsubseries
      when "ietf-internet-drafts" then fetch_ieft_internet_drafts
      when "ietf-rfc-entries" then fetch_ieft_rfcs
      end
      @index.save
    end

    #
    # Fetches ietf-rfcsubseries documents
    #
    def fetch_ieft_rfcsubseries
      rfc_index.xpath("xmlns:bcp-entry|xmlns:fyi-entry|xmlns:std-entry").each do |doc|
        save_doc RfcIndexEntry.parse(doc)
      end
    end

    #
    # Fetches ietf-internet-drafts documents
    #
    def fetch_ieft_internet_drafts # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      versions = Dir["bibxml-ids/*.xml"].each_with_object([]) do |path, vers|
        file = File.basename path, ".xml"
        if file.include?("D.draft-")
          vers << file.sub(/^reference\.I-D\./, "").downcase
          /(?<ver>\d+)$/ =~ file
        end
        bib = BibXMLParser.parse(File.read(path, encoding: "UTF-8"))
        if ver
          version = RelatonBib::BibliographicItem::Version.new nil, ver
          bib.instance_variable_set :@version, [version]
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
            bib_versions = versions.grep(/^#{Regexp.quote match[:series]}-\d{2}/)
            create_series match[:series], bib_versions
            series = match[:series]
          end
          lv = bib_versions.select { |ref| ref.match(/\d+$/).to_s.to_i < match[:ver].to_i }
          hv = bib_versions.select { |ref| ref.match(/\d+$/).to_s.to_i > match[:ver].to_i }
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
      vs = versions.sort_by { |v| v.match(/\d+$/).to_s.to_i }
      fref = RelatonBib::FormattedRef.new content: ref
      docid = RelatonBib::DocumentIdentifier.new type: "Internet-Draft", id: ref, primary: true
      rel = vs.map { |v| version_relation v, "includes" }
      last_v = HashConverter.hash_to_bib YAML.load_file("#{@output}/#{vs.last}.#{@ext}")
      bib = IetfBibliographicItem.new(
        title: last_v[:title], abstract: last_v[:abstract], formattedref: fref,
        docid: [docid], relation: rel
      )
      save_doc bib
    end

    #
    # Create bibitem relation
    #
    # @param [String] ref reference
    # @param [String] type relation type
    #
    # @return [RelatonBib::DocumentRelation] relation
    #
    def version_relation(ref, type)
      fref = RelatonBib::FormattedRef.new content: ref
      docid = RelatonBib::DocumentIdentifier.new type: "Internet-Draft", id: ref, primary: true
      bibitem = IetfBibliographicItem.new formattedref: fref, docid: [docid]
      RelatonBib::DocumentRelation.new(type: type, bibitem: bibitem)
    end

    #
    # Redad saved documents
    #
    # @param [String] file path to file
    #
    # @return [RelatonIetf::IetfBibliographicItem] bibliographic item
    #
    def read_doc(file)
      doc = File.read(file, encoding: "UTF-8")
      case @format
      when "xml" then XMLParser.from_xml(doc)
      when "yaml" then IetfBibliographicItem.from_hash YAML.safe_load(doc)
      else BibXMLParser.parse(doc)
      end
    end

    #
    # Fetches ietf-rfc-entries documents
    #
    def fetch_ieft_rfcs
      rfc_index.xpath("xmlns:rfc-entry").each do |doc|
        save_doc RfcEntry.parse(doc)
      rescue StandardError => e
        Util.error "Error parsing #{doc.at('./xmlns:doc-id').text}: #{e.message}\n" \
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
      Nokogiri::XML(Net::HTTP.get(uri)).at("/xmlns:rfc-index")
    end

    #
    # Save document to file
    #
    # @param [RelatonIetf::RfcIndexEntry, nil] rfc index entry
    # @param [Boolean] check_duplicate check for duplicate
    #
    def save_doc(entry, check_duplicate: true) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
      return unless entry

      c = case @format
          when "xml" then entry.to_xml(bibdata: true)
          when "yaml" then entry.to_hash.to_yaml
          else entry.send("to_#{@format}")
          end
      file = file_name entry
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
      @index.add_or_update docid.id, file
    end

    #
    # Generate file name
    #
    # @param [RelatonIetf::RfcIndexEntry] entry
    #
    # @return [String] file name
    #
    def file_name(entry) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
      id = if entry.respond_to? :docidentifier
             entry.docidentifier.detect { |i| i.type == "Internet-Draft" }&.id
           end
      id ||= entry.docnumber || entry.formattedref.content
      if @source == "ietf-internet-drafts" then id.downcase!
      else id.upcase!
      end
      name = id.gsub(/[\s,:\/]/, "_").squeeze("_")
      File.join @output, "#{name}.#{@ext}"
    end
  end
end
