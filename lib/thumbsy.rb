# frozen_string_literal: true

require "thumbsy/version"
require "thumbsy/extension"
require "thumbsy/engine"
require "thumbsy/votable"
require "thumbsy/voter"


module Thumbsy
  # Basic configuration
  mattr_accessor :vote_model_name
  self.vote_model_name = "ThumbsyVote"

  def self.configure
    yield(self)
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
if defined?(ActiveRecord::Base) && !defined?(Thumbsy::Engine)
  ActiveRecord::Base.extend(Thumbsy::Extension)
end
