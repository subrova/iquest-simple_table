# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'iquest/simple_table/version'

Gem::Specification.new do |spec|
  spec.name          = "iquest-simple_table"
  spec.version       = Iquest::SimpleTable::VERSION
  spec.authors       = ["Pavel Dusanek"]
  spec.email         = ["dusanek@iquest.cz"]
  spec.description   = "Simple table helper"
  spec.summary       = "Simple table helper, taht supports filtering through Ransack"
  spec.homepage      = "https://github.com/iquest/iquest-simple_table"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency 'ransack_simple_form', github: 'subrova/ransack_simple_form'
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "relaxed-rubocop"
  spec.add_development_dependency "rubocop"
end
