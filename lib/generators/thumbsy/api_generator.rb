# frozen_string_literal: true

require "rails/generators"

module Thumbsy
  module Generators
    class ApiGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)
      desc "Generate Thumbsy API configuration and routes"

      def create_api_initializer
        copy_file "thumbsy_api.rb", "config/initializers/thumbsy_api.rb"
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
