require "rubygems"
require "rubygems/package"
require "zlib"
require "relaton_ietf/rfc_index_entry"

module RelatonIetf
  class DataFetcher
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
      @format = source == "ietf-rfcsubseries" ? "xml" : format
      @ext = @format.sub(/^bib/, "")
      @files = []
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
      FileUtils.mkdir_p output unless Dir.exist? output
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
      end
    end

    #
    # Fetches ietf-rfcsubseries documents
    #
    def fetch_ieft_rfcsubseries
      uri = URI "https://www.rfc-editor.org/rfc-index.xml"
      resp = Net::HTTP.get uri
      index = Nokogiri::XML(resp).at("/xmlns:rfc-index")
      index.xpath("xmlns:bcp-entry|xmlns:fyi-entry|xmlns:std-entry").each do |doc|
        save_doc RfcIndexEntry.parse(doc)
      end
    end

    #
    # Fetches ietf-internet-drafts documents
    #
    def fetch_ieft_internet_drafts # rubocop:disable Metrics/MethodLength
      gz = OpenURI.open_uri("https://www.ietf.org/lib/dt/sprint/bibxml-ids.tgz")
      z = Zlib::GzipReader.new(gz)
      io = StringIO.new(z.read)
      # File.write "bibxml3.tar", z.read, encoding: "UTF-8"
      z.close
      Gem::Package::TarReader.new io do |tar|
        tar.each do |tarfile|
          next if tarfile.directory?

          save_doc RelatonBib::BibXMLParser.parse(tarfile.read)
        end
      end
    end

    #
    # Save document to file
    #
    # @param [RelatonIetf::RfcIndexEntry, nil] rfc index entry
    #
    def save_doc(entry) # rubocop:disable Metrics/MethodLength
      return unless entry

      c = case @format
          when "xml" then entry.to_xml(bibdata: true)
          when "yaml" then entry.to_hash.to_yaml
          else entry.send("to_#{@format}")
          end
      file = file_name entry
      if @files.include? file
        warn "File #{file} already exists. Document: #{entry.docnumber}"
      else
        @files << file
      end
      File.write file, c, encoding: "UTF-8"
    end

    #
    # Generate file name
    #
    # @param [RelatonIetf::RfcIndexEntry] entry
    #
    # @return [String] file name
    #
    def file_name(entry)
      id = entry.docidentifier.detect { |i| i.type == "Internet-Draft" }&.id
      id ||= entry.docnumber
      name = id.gsub(/[\s,:\/]/, "_").squeeze("_").upcase
      File.join @output, "#{name}.#{@ext}"
    end
  end
end
