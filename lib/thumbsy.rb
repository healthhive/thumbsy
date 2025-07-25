# frozen_string_literal: true

require "thumbsy/version"
require "thumbsy/extension"
require "thumbsy/engine"
require "thumbsy/votable"
require "thumbsy/voter"
require "thumbsy/configuration"
require "thumbsy/api/configuration"

module Thumbsy
  class << self
    attr_accessor :config
  end

  def self.configure
    self.config ||= Configuration.new
    yield(config)
    # Ensure feedback_options validation is set up after configuration
    return unless defined?(ThumbsyVote) && config.feedback_options.present?

    ThumbsyVote.setup_feedback_options_validation!
  end

  def self.feedback_options
    config&.feedback_options
  end

  def self.feedback_options=(options)
    self.config ||= Configuration.new
    config.feedback_options = options
  end

  def self.api_config
    config&.api_config
  end

  # Load API functionality (optional)
  def self.load_api!
    require "thumbsy/api" unless defined?(Thumbsy::Api)
    Thumbsy::Api.load!
  end

  # Autoload API module when accessed
  def self.const_missing(name)
    if name == :Api
      require "thumbsy/api"
      const_get(name)
    else
      super
    end
  end
end

# Extend ActiveRecord when available (fallback if Rails engine doesn't load)
ActiveRecord::Base.extend(Thumbsy::Extension) if defined?(ActiveRecord::Base) && !defined?(Thumbsy::Engine)

require_relative "thumbsy/models/thumbsy_vote"
