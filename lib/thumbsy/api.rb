# frozen_string_literal: true

module Thumbsy
  module Api
    # API configuration
    mattr_accessor :require_authentication
    self.require_authentication = true

    mattr_accessor :require_authorization
    self.require_authorization = false

    mattr_accessor :authentication_method
    self.authentication_method = nil

    mattr_accessor :current_voter_method
    self.current_voter_method = nil

    mattr_accessor :authorization_method
    self.authorization_method = nil

    mattr_accessor :voter_serializer
    self.voter_serializer = nil

    def self.configure
      yield(self)
    end

    # Load API components
    def self.load!
      require "thumbsy/api/engine"
      require "thumbsy/api/controllers/application_controller"
      require "thumbsy/api/controllers/votes_controller"
    end

    # Custom exceptions
    class AuthenticationError < StandardError; end
    class AuthorizationError < StandardError; end
  end
end
