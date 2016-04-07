# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wamp_client/version'

Gem::Specification.new do |spec|
  spec.name          = 'wamp_client'
  spec.version       = WampClient::VERSION
  spec.authors       = ['Eric Chapman']
  spec.email         = ['eric.chappy@gmail.com']
  spec.summary       = %q{Web Application Messaging Protocol Client}
  spec.description   = %q{An implementation of The Web Application Messaging Protocol (WAMP)}
  spec.homepage      = ''
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
  spec.add_development_dependency 'rspec'

  spec.add_dependency 'websocket', '~> 1.2.3'
end
