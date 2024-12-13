# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "relaton_ietf/version"

Gem::Specification.new do |spec|
  spec.name          = "relaton-ietf"
  spec.version       = RelatonIetf::VERSION
  spec.authors       = ["Ribose Inc."]
  spec.email         = ["open.source@ribose.com"]

  spec.summary       = "RelatonIetf: retrieve IETF Standards for " \
                       "bibliographic use using the BibliographicItem model"
  spec.description   = <<~DESCRIPTION
    RelatonIetf: retrieve IETF Standards for bibliographic use
    using the BibliographicItem model.

    Formerly known as rfcbib.
  DESCRIPTION
  spec.homepage      = "https://github.com/metanorma/relaton-ietf"
  spec.license       = "BSD-2-Clause"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.required_ruby_version = Gem::Requirement.new(">= 2.7.0")

  spec.add_dependency "base64"
  spec.add_dependency "relaton-bib", "~> 1.20.0"
  spec.add_dependency "relaton-index", "~> 0.2.3"
end
