require "relaton_ietf/rfc_index_entry"

module RelatonIetf
  class RfcIndexFetcher
    #
    # Data fetcher initializer
    #
    # @param [String] output directory to save files
    # @param [String] format format of output files (xml, yaml, bibxml)
    #
    def initialize(output, format)
      @output = output
      @format = format
      @ext = format.sub(/^bib/, "")
      @files = []
    end

    #
    # Initialize fetcher and run fetch
    #
    # @param [Strin] output directory to save files, default: "data"
    # @param [Strin] format format of output files (xml, yaml, bibxml), default: yaml
    #
    def self.fetch(output: "data", format: "yaml")
      t1 = Time.now
      puts "Started at: #{t1}"
      FileUtils.mkdir_p output unless Dir.exist? output
      new(output, format).fetch
      t2 = Time.now
      puts "Stopped at: #{t2}"
      puts "Done in: #{(t2 - t1).round} sec."
    end

    #
    # Parse documents
    #
    def fetch
      uri = URI "https://www.rfc-editor.org/rfc-index.xml"
      resp = Net::HTTP.get uri
      index = Nokogiri::XML(resp).at("/xmlns:rfc-index")
      index.xpath("xmlns:bcp-entry|xmlns:fyi-entry|xmlns:std-entry").each do |doc|
        save_doc RfcIndexEntry.parse(doc)
      end
    end

    #
    # Save document to file
    #
    # @param [RelatonIetf::RfcIndexEntry, nil] rfc index entry
    #
    def save_doc(entry) # rubocop:disable Metrics/MethodLength
      return unless entry&.has_also?

      file = entry.filename(@output)
      if @files.include? file
        warn "File #{file} already exists. Document: #{bib.docnumber}"
      else
        @files << file
      end
      File.write file, entry.to_xml, encoding: "UTF-8"
    end
  end
end
