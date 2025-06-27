# frozen_string_literal: true

require "thumbsy/version"
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
    require "thumbsy/api"
    Thumbsy::Api.load!
  end
end
