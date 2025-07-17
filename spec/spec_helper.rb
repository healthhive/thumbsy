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
end

# Load the gem
require "thumbsy"

# Ensure Thumbsy extension is applied to ActiveRecord::Base for test macros
ActiveRecord::Base.extend(Thumbsy::Extension)

RSpec.configure do |config|
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

  # Dynamically define ThumbsyVote model for tests using the generator template
  config.before(:suite) do
    Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)

    # Read the generator template
    template_path = File.expand_path("../lib/generators/thumbsy/templates/thumbsy_vote.rb.tt", __dir__)
    template_content = File.read(template_path)

    # Use default feedback options (same as generator default)
    feedback_options = %w[like dislike funny]

    # Process the template manually by replacing the ERB placeholder
    model_code = template_content.gsub(
      "<%== feedback_options.map(&:inspect).join(', ') %>",
      feedback_options.map(&:inspect).join(", "),
    )

    # Evaluate the processed template safely
    # rubocop:disable Security/Eval
    eval(model_code, TOPLEVEL_BINDING)
    # rubocop:enable Security/Eval

    # Create tables for test models
    ActiveRecord::Base.connection.create_table(:thumbsy_votes, force: true) do |t|
      t.references :votable, polymorphic: true, null: false
      t.references :voter, polymorphic: true, null: false
      t.boolean :vote, null: false
      t.text :comment
      t.integer :feedback_option
      t.timestamps
    end

    ActiveRecord::Base.connection.create_table(:users, force: true) do |t|
      t.string :name
      t.timestamps
    end

    ActiveRecord::Base.connection.create_table(:books, force: true) do |t|
      t.string :title
      t.timestamps
    end

    # Create tables for edge case test models
    ActiveRecord::Base.connection.create_table(:non_votable_items, force: true) do |t|
      t.string :name
      t.timestamps
    end

    ActiveRecord::Base.connection.create_table(:non_voter_items, force: true) do |t|
      t.string :name
      t.timestamps
    end

    ActiveRecord::Base.connection.create_table(:articles, force: true) do |t|
      t.string :title
      t.text :content
      t.timestamps
    end
  end

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end
end
