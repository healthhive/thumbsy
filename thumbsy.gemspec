# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "thumbsy"
  spec.version       = "1.0.0"
  spec.authors       = ["Tiago"]
  spec.email         = ["tiago@example.com"]

  spec.summary       = "A Rails gem for adding voting/liking functionality to ActiveRecord models"
  spec.description   = "Thumbsy provides an easy way to add thumbs up/down or like/dislike functionality " \
                       "to your Rails models with comments support"
  spec.homepage      = "https://github.com/yourusername/thumbsy"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.3.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/yourusername/thumbsy.git"
  spec.metadata["changelog_uri"] = "https://github.com/yourusername/thumbsy/blob/main/docs/changelog.md"
  spec.metadata["documentation_uri"] = "https://github.com/yourusername/thumbsy/blob/main/docs/api-guide.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/yourusername/thumbsy/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "rails", ">= 7.0", "< 9.0"
  spec.add_development_dependency "rack-test", "~> 2.0"
  spec.add_development_dependency "rspec-rails", "~> 6.0"
  spec.add_development_dependency "sqlite3", "~> 1.4"
end
