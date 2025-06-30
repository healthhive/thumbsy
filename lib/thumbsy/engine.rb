# frozen_string_literal: true

module Thumbsy
  # Only define Rails engine when Rails is available
  if defined?(Rails)
    class Engine < ::Rails::Engine
      isolate_namespace Thumbsy

      config.generators do |g|
        g.test_framework :rspec
      end

      initializer "thumbsy.active_record" do
        ActiveSupport.on_load(:active_record) do
          extend Thumbsy::Extension
        end
      end
    end
  end
end
