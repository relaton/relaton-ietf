# frozen_string_literal: true

require_relative "is_also"
require_relative "author"
require_relative "entry_date"
require_relative "format"
require_relative "keywords"
require_relative "abstract"
require_relative "../bibxml_parser"

module Relaton
  module Ietf
    module Rfc
      # Model for index entries (bcp-entry, fyi-entry, std-entry, rfc-entry)
      class Entry < Lutaml::Model::Serializable # rubocop:disable Metrics/ClassLength
        NAMESPACE = "https://www.rfc-editor.org/rfc-index"

        TITLE_PREFIXES = {
          "bcp" => "Best Current Practice",
          "fyi" => "For Your Information",
          "std" => "Internet Standard technical specification",
        }.freeze

        # Common attributes
        attribute :doc_id, :string
        attribute :title, :string
        attribute :is_also, IsAlso
        attribute :stream, :string

        # rfc-entry specific attributes
        attribute :author, Author, collection: true
        attribute :date, EntryDate, collection: true
        attribute :format, Format
        attribute :page_count, :integer
        attribute :keywords, Keywords
        attribute :abstract, Abstract
        attribute :obsoletes, IsAlso
        attribute :obsoleted_by, IsAlso
        attribute :updates, IsAlso
        attribute :updated_by, IsAlso
        attribute :see_also, IsAlso
        attribute :current_status, :string
        attribute :publication_status, :string
        attribute :wg_acronym, :string
        attribute :errata_url, :string
        attribute :doi, :string

        xml do
          root "bcp-entry"
          namespace NAMESPACE

          map_element "doc-id", to: :doc_id
          map_element "title", to: :title
          map_element "is-also", to: :is_also
          map_element "stream", to: :stream
          map_element "author", to: :author
          map_element "date", to: :date
          map_element "format", to: :format
          map_element "page-count", to: :page_count
          map_element "keywords", to: :keywords
          map_element "abstract", to: :abstract
          map_element "obsoletes", to: :obsoletes
          map_element "obsoleted-by", to: :obsoleted_by
          map_element "updates", to: :updates
          map_element "updated-by", to: :updated_by
          map_element "see-also", to: :see_also
          map_element "current-status", to: :current_status
          map_element "publication-status", to: :publication_status
          map_element "wg_acronym", to: :wg_acronym
          map_element "errata-url", to: :errata_url
          map_element "doi", to: :doi
        end

        #
        # Determine entry type from doc-id prefix
        #
        # @return [String, nil] entry type (bcp, fyi, std, rfc)
        #
        def entry_type
          doc_id&.downcase&.match(/^(bcp|fyi|std|rfc)/)&.[](1)
        end

        #
        # Check if this is an rfc-entry
        #
        # @return [Boolean]
        #
        def rfc_entry?
          entry_type == "rfc"
        end

        #
        # Extract short number from doc-id (e.g., "BCP0001" -> "1")
        #
        # @return [String] short number without leading zeros
        #
        def shortnum
          doc_id&.match(/\d+$/)&.to_s&.sub(/^0+/, "") || ""
        end

        #
        # Generate public identifier (e.g., "BCP 1")
        #
        # @return [String] public identifier
        #
        def pub_id
          "#{entry_type&.upcase} #{shortnum}"
        end

        #
        # Generate anchor string (e.g., "BCP1")
        #
        # @return [String] anchor
        #
        def anchor
          "#{entry_type&.upcase}#{shortnum}"
        end

        #
        # Check if this entry has is-also references
        #
        # @return [Boolean]
        #
        def has_is_also?
          is_also&.doc_id&.any? || false
        end

        #
        # Convert to Relaton::Ietf::ItemData
        #
        # @param rfc_index [Hash{String => Entry}, nil] lookup of RFC entries by doc-id
        # @return [Relaton::Ietf::ItemData, nil]
        #
        def to_item(rfc_index = nil, wg_names: {})
          if rfc_entry?
            to_rfc_item(wg_names: wg_names)
          else
            to_subseries_item(rfc_index, wg_names: wg_names)
          end
        end

        def to_rfc_item(wg_names: {}) # rubocop:disable Metrics/MethodLength
          args = {
            type: "standard",
            language: ["en"],
            script: ["Latn"],
            docidentifier: build_rfc_docid,
            docnumber: doc_id,
            title: build_rfc_title,
            source: build_rfc_link,
            date: build_rfc_date,
            contributor: build_rfc_contributor(wg_names),
            status: build_rfc_status,
            keyword: build_rfc_keyword,
            abstract: build_rfc_abstract,
            relation: build_rfc_relation,
            series: build_rfc_series,
            ext: build_rfc_ext,
          }
          ItemData.new(**args)
        end

        private

        def to_subseries_item(rfc_index = nil, wg_names: {})
          return unless doc_id && has_is_also?

          ItemData.new(
            type: "standard",
            docnumber: doc_id,
            title: build_title,
            docidentifier: build_docid,
            language: ["en"],
            script: ["Latn"],
            source: build_link,
            formattedref: build_formattedref,
            relation: build_relations(rfc_index, wg_names: wg_names),
            series: build_series,
            ext: Ext.new(flavor: "ietf"),
          )
        end

        # --- Subseries builders ---

        def build_title
          type = entry_type
          return [] unless type

          prefix = TITLE_PREFIXES[type]
          content = "#{prefix} #{shortnum}"
          [Bib::Title.new(content: content, language: "en", script: "Latn")]
        end

        def build_docid
          [Bib::Docidentifier.new(type: "IETF", content: pub_id, primary: true)]
        end

        def build_link
          type = entry_type
          return [] unless type

          url = "https://www.rfc-editor.org/info/#{type}#{shortnum}"
          [Bib::Uri.new(type: "src", content: url)]
        end

        def build_formattedref
          anchor
        end

        def build_relations(rfc_index = nil, wg_names: {})
          return [] unless is_also&.doc_id

          is_also.doc_id.map do |ref|
            rfc_entry = rfc_index&.[](ref)
            bibitem = rfc_entry ? rfc_entry.to_rfc_item(wg_names: wg_names) : build_minimal_bibitem(ref)
            Bib::Relation.new(type: "includes", bibitem: bibitem)
          end.compact
        end

        def build_minimal_bibitem(ref)
          id = ref.sub(/^([A-Z]+)0*(\d+)$/, '\1 \2')
          docid = Bib::Docidentifier.new(type: "IETF", content: id, primary: true)
          ItemData.new(formattedref: ref, docidentifier: [docid])
        end

        def build_series
          return [] unless stream

          t = Bib::Title.new(content: stream)
          [Bib::Series.new(type: "stream", title: [t])]
        end

        # --- RFC entry builders ---

        def build_rfc_docid
          ids = [Bib::Docidentifier.new(type: "IETF", content: "RFC #{shortnum}", primary: true)]
          ids << Bib::Docidentifier.new(type: "DOI", content: doi) if doi
          ids
        end

        def build_rfc_title
          [Bib::Title.new(content: title, type: "main")]
        end

        def build_rfc_link
          [Bib::Uri.new(type: "src", content: "https://www.rfc-editor.org/info/rfc#{shortnum}")]
        end

        def build_rfc_date
          (date || []).map do |d|
            month_num = ::Date::MONTHNAMES.index(d.month).to_s.rjust(2, "0")
            date_str = "#{d.year}-#{month_num}"
            Bib::Date.new(at: date_str, type: "published")
          end
        end

        def build_rfc_contributor(wg_names = {}) # rubocop:disable Metrics/MethodLength
          contribs = (author || []).map do |a|
            entity = full_name_org(a.name)
            unless entity
              fname = parse_person_name(a.name)
              entity = Bib::Person.new(name: fname)
            end
            role_type = a.role_title&.downcase || "author"
            Bib::Contributor.new(**entity_from(entity), role: [Bib::Contributor::Role.new(type: role_type)])
          end
          contribs << org_contributor("RFC Publisher", "publisher")
          contribs << org_contributor("RFC Series", "authorizer")
          committee = build_committee_contributor(wg_names)
          contribs << committee if committee
          contribs
        end

        def entity_from(entity)
          if entity.is_a?(Bib::Organization)
            { organization: entity }
          else
            { person: entity }
          end
        end

        def org_contributor(org_name, role_type)
          org = Ietf::BibXMLParser.build_org(nil, org_name)
          Bib::Contributor.new(organization: org, role: [Bib::Contributor::Role.new(type: role_type)])
        end

        def full_name_org(name)
          Ietf::BibXMLParser.full_name_org(name)
        end

        def parse_person_name(name) # rubocop:disable Metrics/MethodLength
          surname, initials, forename = Ietf::BibXMLParser.parse_surname_initials(name, nil, nil)
          args = {
            completename: Bib::LocalizedString.new(content: name, language: "en", script: "Latn"),
            surname: Bib::LocalizedString.new(content: surname, language: "en", script: "Latn"),
          }
          args[:formatted_initials] = Bib::LocalizedString.new(content: initials, language: "en", script: "Latn") if initials
          forenames = []
          if forename
            forenames << Bib::FullNameType::Forename.new(content: forename, language: "en", script: "Latn")
          end
          if initials
            initials.split(/\.-?\s?|\s/).each do |i|
              forenames << Bib::FullNameType::Forename.new(initial: i, language: "en", script: "Latn")
            end
          end
          args[:forename] = forenames
          Bib::FullName.new(**args)
        end

        def build_rfc_keyword
          (keywords&.kw || []).map do |kw|
            taxon = Bib::LocalizedString.new(content: kw)
            Bib::Keyword.new(taxon: [taxon])
          end
        end

        def build_rfc_abstract
          return [] unless abstract&.p&.any?

          content = abstract.p.map { |para| "<p>#{para.strip}</p>" }.join
          [Bib::LocalizedMarkedUpString.new(content: content, language: "en", script: "Latn")]
        end

        def build_rfc_relation
          rels = []
          if updates&.doc_id
            updates.doc_id.each do |ref|
              rels << build_rfc_doc_relation(ref, "updates")
            end
          end
          if obsoleted_by&.doc_id
            obsoleted_by.doc_id.each do |ref|
              rels << build_rfc_doc_relation(ref, "obsoletedBy")
            end
          end
          rels
        end

        def build_rfc_doc_relation(ref, type)
          docid = Bib::Docidentifier.new(type: "IETF", content: ref, primary: true)
          bibitem = ItemData.new(formattedref: ref, docidentifier: [docid])
          Bib::Relation.new(type: type, bibitem: bibitem)
        end

        def build_rfc_status
          return unless current_status

          Bib::Status.new(stage: Bib::Status::Stage.new(content: current_status))
        end

        def build_rfc_series
          series = build_rfc_is_also_series
          series << Bib::Series.new(title: [Bib::Title.new(content: "RFC")], number: shortnum)
          series + build_rfc_stream_series
        end

        def build_rfc_is_also_series
          return [] unless is_also&.doc_id

          is_also.doc_id.map do |s|
            /^(?<name>\D+)(?<num>\d+)/ =~ s
            t = Bib::Title.new(content: name)
            Bib::Series.new(title: [t], number: num.gsub(/^0+/, ""))
          end
        end

        def build_rfc_stream_series
          return [] unless stream

          t = Bib::Title.new(content: stream)
          [Bib::Series.new(type: "stream", title: [t])]
        end

        STREAM_ORGS = {
          "IETF" => ["IETF", "Internet Engineering Task Force"],
          "IRTF" => ["IRTF", "Internet Research Task Force"],
          "IAB" => ["IAB", "Internet Architecture Board"],
        }.freeze

        def build_rfc_ext
          Ext.new(stream: stream, flavor: "ietf")
        end

        def build_committee_contributor(wg_names = {})
          return if wg_acronym.nil? || wg_acronym == "NON WORKING GROUP"

          abbr, name = STREAM_ORGS[stream]
          org = if abbr
                  Ietf::BibXMLParser.build_org(abbr, name)
                else
                  Ietf::BibXMLParser.build_org(nil, stream || "IETF")
                end
          full_name = wg_names[wg_acronym] || wg_acronym
          subdivision = Bib::Subdivision.new(
            type: "workgroup",
            name: [Bib::TypedLocalizedString.new(content: full_name)],
            identifier: [Bib::OrganizationType::Identifier.new(content: wg_acronym)],
          )
          org.subdivision = [subdivision]
          role = Bib::Contributor::Role.new(
            type: "author",
            description: [Bib::LocalizedMarkedUpString.new(content: "committee")],
          )
          Bib::Contributor.new(organization: org, role: [role])
        end
      end
    end
  end
end
