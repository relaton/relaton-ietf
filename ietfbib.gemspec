# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ietfbib/version'

Gem::Specification.new do |spec|
  spec.name          = 'ietfbib'
  spec.version       = IETFBib::VERSION
  spec.authors       = ['Ribose Inc.']
  spec.email         = ['open.source@ribose.com']

  spec.summary       = 'ietfbib: retrieve IETF Standards for bibliographic use '\
                       'using the BibliographicItem model'
  spec.description   = <<~DESCRIPTION
                        ietfbib: retrieve IETF Standards for bibliographic use 
                        using the BibliographicItem model.

                        Formerly known as rfcbib.
                       DESCRIPTION
  spec.homepage      = 'https://github.com/riboseinc/ietfbib'
  spec.license       = 'BSD-2-Clause'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'equivalent-xml', '~> 0.6'
  spec.add_development_dependency 'pry-byebug'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec', '~> 3.0'
  spec.add_development_dependency 'simplecov'

  spec.add_dependency 'iso-bib-item', '~> 0.4.1'
end
