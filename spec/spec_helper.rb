# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

# Start SimpleCov for coverage reporting
if ENV["COVERAGE"] == "true" || ENV["CI"]
  require "simplecov"
  SimpleCov.start do
    add_filter "/spec/"
    add_filter "/vendor/"
    minimum_coverage 78
  end
end

require "bundler/setup"

# Load RSpec components
require "rspec/core"
require "rspec/expectations"
require "rspec/mocks"

# Load Rails components
require "active_record"
require "rails"
require "action_controller"
require "action_dispatch"
require "action_dispatch/testing/integration"

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
    t.integer :feedback_option
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

  # Add missing edge case tables
  create_table :non_voter_items, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :non_votable_items, force: true do |t|
    t.string :name
    t.timestamps
  end

  create_table :articles, force: true do |t|
    t.string :title
    t.text :content
    t.timestamps
  end
end

# Load the gem
require "thumbsy"

# Require the ThumbsyVote model from the gem
require_relative "../lib/thumbsy/models/thumbsy_vote"

# Ensure Thumbsy extension is applied to ActiveRecord::Base for test macros
ActiveRecord::Base.extend(Thumbsy::Extension)

RSpec.configure do |config|
  # Set up Thumbsy config for tests
  Thumbsy.configure do |c|
    c.feedback_options = %w[like dislike funny]
    c.api do |api|
      api.require_authentication = false
      api.authentication_method = nil
      api.current_voter_method = -> { User.first }
    end
  end
  config.mock_with :rspec
  config.order = "random"
  config.filter_run_when_matching :focus

  # Include request spec helpers
  config.include ActionDispatch::IntegrationTest, type: :request
  config.include ActionDispatch::TestProcess, type: :request

  # Clean database between tests (skip for performance tests)
  config.before(:each) do |example|
    unless example.metadata[:performance]
      ThumbsyVote.delete_all
      User.delete_all if defined?(User)
      Book.delete_all if defined?(Book)
    end
  end

  # Remove obsolete dynamic model generation for ThumbsyVote

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
