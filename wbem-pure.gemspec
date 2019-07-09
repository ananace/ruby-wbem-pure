# frozen_string_literal: true

require File.join(File.expand_path('lib', __dir__), 'wbem/version')

Gem::Specification.new do |spec|
  spec.name          = 'wbem-pure'
  spec.version       = Wbem::VERSION
  spec.authors       = ['Alexander Olofsson']
  spec.email         = ['alexander.olofsson@liu.se']

  spec.summary       = 'Pure Ruby WBEM implementation'
  spec.description   = 'Ruby gem for communicating with WBEM servers'
  spec.homepage      = 'https://github.com/ananace/ruby-wbem-pure'
  spec.license       = 'MIT'

  spec.extra_rdoc_files = ['LICENSE.txt', 'README.md']
  spec.files            = Dir['{bin,lib}/**/*'] + spec.extra_rdoc_files
  spec.executables      = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }

  spec.add_dependency 'logging', '~> 2.2'
  spec.add_dependency 'net-http-digest_auth', '~> 1.4'
  spec.add_dependency 'nokogiri', '~> 1.8'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 10.0'
end
