# frozen_string_literal: true

source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

gemspec

# Database adapters for CI testing
gem "sqlite3", "~> 2.1"

# SQLite only for now - can add other databases later

# Rails dependencies
gem "sprockets-rails", "~> 3.4"

# Rails version - dynamically set by CI matrix or default for local development
# Supports Rails 7.1, 7.2, and 8.0+
rails_version = ENV.fetch("RAILS_VERSION", "7.2")
if rails_version == "main"
  gem "rails", github: "rails/rails", branch: "main"
else
  gem "rails", "~> #{rails_version}.0"
end

group :development, :test do
  gem "rspec-rails", "~> 6.0"

  gem "database_cleaner-active_record", "~> 2.1"
  gem "rspec_junit_formatter", "~> 0.6"
  gem "simplecov", "~> 0.22", require: false
end

group :development do
  gem "rubocop", "~> 1.57", require: false
  gem "rubocop-rails", "~> 2.22", require: false
  gem "rubocop-rspec", "~> 2.25", require: false
end

group :test do
  gem "timecop", "~> 0.9"
  gem "webmock", "~> 3.18"
end
