# frozen_string_literal: true

module Thumbsy
  class Configuration
    attr_accessor :api_config

    def initialize
      @api_config = Thumbsy::Api::Configuration.new
    end

    def api
      yield @api_config if block_given?
      @api_config
    end

    def feedback_options=(options)
      @feedback_options = options
      # Automatically set up validation if ThumbsyVote is loaded
      ThumbsyVote.setup_feedback_options_validation! if defined?(ThumbsyVote)
    end

    attr_reader :feedback_options
  end
end
