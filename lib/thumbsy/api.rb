# frozen_string_literal: true

module Thumbsy
  module Api
    def self.require_authentication
      Thumbsy.api_config.require_authentication
    end

    def self.authentication_method
      Thumbsy.api_config.authentication_method
    end

    def self.current_voter_method
      Thumbsy.api_config.current_voter_method
    end

    def self.require_authorization
      Thumbsy.api_config.require_authorization
    end

    def self.require_authorization=(value)
      Thumbsy.api_config.require_authorization = value
    end

    def self.authorization_method
      Thumbsy.api_config.authorization_method
    end

    def self.authorization_method=(value)
      Thumbsy.api_config.authorization_method = value
    end

    def self.voter_serializer
      Thumbsy.api_config.voter_serializer
    end

    def self.voter_serializer=(value)
      Thumbsy.api_config.voter_serializer = value
    end

    def self.configure
      yield(Thumbsy.api_config)
    end

    # Load API components
    def self.load!
      require "thumbsy/api/engine"
      require "thumbsy/api/controllers/application_controller"
      require "thumbsy/api/controllers/votes_controller"
      require "thumbsy/api/serializers/vote_serializer"
    end

    # Custom exceptions
    class AuthenticationError < StandardError; end
    class AuthorizationError < StandardError; end
  end
end
