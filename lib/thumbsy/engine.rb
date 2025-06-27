# frozen_string_literal: true

module Thumbsy
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

  module Extension
    def votable(_options = {})
      include Thumbsy::Votable
    end

    def voter(_options = {})
      include Thumbsy::Voter
    end
  end
end
