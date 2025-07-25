# frozen_string_literal: true

module Thumbsy
  module Api
    class Engine < ::Rails::Engine
      isolate_namespace Thumbsy::Api

      # Load API routes from routes.rb file
      config.after_initialize do
        require "thumbsy/api/routes"
      end
    end
  end
end
