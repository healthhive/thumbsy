# frozen_string_literal: true

module Thumbsy
  class Configuration
    attr_accessor :feedback_options, :api_config

    def initialize
      @feedback_options = nil
      @api_config = Thumbsy::Api::Configuration.new
    end

    def api
      yield @api_config if block_given?
      @api_config
    end
  end
end
