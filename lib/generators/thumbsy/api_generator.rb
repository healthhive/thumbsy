# frozen_string_literal: true

require "rails/generators"

module Thumbsy
  module Generators
    class ApiGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Generate Thumbsy API configuration and routes"

      def create_api_initializer
        initializer_path = "config/initializers/thumbsy.rb"
        require_line = "require 'thumbsy/api'"
        load_line = "Thumbsy::Api.load!"
        insert_lines = "# Load Thumbsy API if you want to use the API endpoints\n#{require_line}\n#{load_line}\n\n"

        if File.exist?(initializer_path)
          content = File.read(initializer_path)
          if content.include?(require_line) && content.include?(load_line)
            say "API require and load lines already present in #{initializer_path}"
          else
            new_content = insert_lines + content
            File.write(initializer_path, new_content)
            say "Added API require and load lines to #{initializer_path}"
          end
        else
          create_file initializer_path, insert_lines
          say "Created #{initializer_path} with API require and load lines"
        end
      end

      def add_api_require
        inject_into_file "config/application.rb", after: "require \"rails/all\"\n" do
          "require \"thumbsy/api\"\n"
        end
      end

      def add_routes
        route_content = <<~RUBY
          # Thumbsy API routes
          mount Thumbsy::Api::Engine => "/api/v1", as: :thumbsy_api
        RUBY

        inject_into_file "config/routes.rb", route_content, after: "Rails.application.routes.draw do\n"
      end

      def show_instructions
        say "Thumbsy API has been configured!"
        say ""
        say "Next steps:"
        say "1. Configure authentication in config/initializers/thumbsy_api.rb"
        say "2. API routes are mounted at /api/v1"
        say "3. Test with: curl -X POST /api/v1/posts/1/vote_up"
        say ""
        say "See API_DOCUMENTATION.md for complete usage examples."
      end
    end
  end
end
