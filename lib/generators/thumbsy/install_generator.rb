# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module Thumbsy
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("templates", __dir__)
      desc "Installs Thumbsy and generates the ThumbsyVote model."

      class_option :feedback, type: :array, desc: "Feedback options for votes (e.g. --feedback like dislike funny)"

      def self.next_migration_number(path)
        next_migration_number = current_migration_number(path) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      class_option :id_type, type: :string, default: :uuid, desc: "ID type for primary keys (uuid, bigint, or integer)"

      def create_migration_file
        @id_type = options[:id_type].to_sym

        if options.key?(:feedback) && (options[:feedback].nil? || options[:feedback].empty?)
          say "\nERROR: --feedback option must have at least one value if provided (e.g. --feedback=like,dislike)", :red
          exit(1)
        end
        migration_template "create_thumbsy_votes.rb", "db/migrate/create_thumbsy_votes.rb"
      end

      def create_thumbsy_vote_model
        feedback_options = options[:feedback] || %w[like dislike funny]
        template "thumbsy_vote.rb.tt", "app/models/thumbsy_vote.rb", feedback_options: feedback_options
      end

      def show_readme
        readme "README" if behavior == :invoke
        say ""
        say "Optional: Generate API endpoints with:"
        say "  rails generate thumbsy:api"
      end
    end
  end
end
