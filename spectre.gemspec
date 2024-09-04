# frozen_string_literal: true

require_relative "lib/spectre/version"

Gem::Specification.new do |s|
  s.name        = 'spectre'
  s.version     = Spectre::VERSION
  s.summary     = "MAV Spectre"
  s.description = "Abstraction layer of making and managing LLM prompts invisible"
  s.authors     = ["Ilya Klapatok", "Matthew Black"]
  s.email       = 'ilya@hiremav.com'
  s.homepage    = 'https://github.com/Vantablack-Holdings/spectre'
  s.license     = 'MIT'

  s.files = Dir.glob("lib/**/*") + %w[README.md CHANGELOG.md]
  s.require_paths = ["lib"]
  # Development dependencies
  s.add_development_dependency 'rspec-rails'
  s.add_development_dependency 'pry'
  s.required_ruby_version = ">= 3"
end
