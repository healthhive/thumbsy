# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module Thumbsy
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration
      source_root File.expand_path("templates", __dir__)
      desc "Generate Thumbsy migration for ActiveRecord voting functionality"

      def self.next_migration_number(path)
        next_migration_number = current_migration_number(path) + 1
        ActiveRecord::Migration.next_migration_number(next_migration_number)
      end

      class_option :id_type, type: :string, default: :uuid, desc: "ID type for primary keys (uuid, bigint, or integer)"

      def create_migration_file
        @id_type = options[:id_type].to_sym
        migration_template "create_thumbsy_votes.rb", "db/migrate/create_thumbsy_votes.rb"
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
