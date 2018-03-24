lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wbem/version'

Gem::Specification.new do |spec|
  spec.name          = 'wbem-pure'
  spec.version       = Wbem::VERSION
  spec.authors       = ['Alexander Olofsson']
  spec.email         = ['alexander.olofsson@liu.se']

  spec.summary       = 'Pure Ruby WBEM implementation'
  spec.description   = 'Ruby gem for communicating with WBEM servers'
  spec.homepage      = 'https://github.com/ananace/ruby-wbem-pure'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'logging', '~> 2.2'
  spec.add_dependency 'net-http-digest_auth', '~> 1.4'
  spec.add_dependency 'nokogiri', '~> 1.8'

  spec.add_development_dependency 'bundler', '~> 1.14'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 10.0'
end
