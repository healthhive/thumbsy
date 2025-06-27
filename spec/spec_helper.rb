# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# Start SimpleCov for coverage reporting
if ENV["COVERAGE"] == "true" || ENV["CI"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/vendor/"
    minimum_coverage 85
  end
end

require "bundler/setup"

# Load Rails components
require "active_record"
require "rails"

# Set up database connection
ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: ":memory:",
)

# Create test schema
ActiveRecord::Schema.define do
  create_table :thumbsy_votes, force: true do |t|
    t.references :votable, null: false, polymorphic: true, index: true
    t.references :voter, null: false, polymorphic: true, index: true
    t.boolean :vote, null: false
    t.text :comment
    t.timestamps null: false

    t.index %i[voter_type voter_id votable_type votable_id],
            unique: true, name: "index_thumbsy_votes_on_voter_and_votable"
    t.index %i[votable_type votable_id vote]
    t.index %i[voter_type voter_id vote]
  end

  create_table :users, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :books, force: true do |t|
    t.string :title
    t.timestamps
  end
end

# Load the gem
require "thumbsy"

# Load the vote model
require_relative "../app/models/thumbsy_vote"

# Manually extend ActiveRecord::Base with our extensions
ActiveRecord::Base.extend(Thumbsy::Extension)

# RSpec is already loaded through the test framework

RSpec.configure do |config|
  config.mock_with :rspec
  config.order = "random"
  config.filter_run_when_matching :focus

  # Clean database between tests (skip for performance tests)
  config.before(:each) do |example|
    unless example.metadata[:performance]
      ThumbsyVote.delete_all
      User.delete_all if defined?(User)
      Book.delete_all if defined?(Book)
    end
  end

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
