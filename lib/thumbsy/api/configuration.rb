# frozen_string_literal: true

module Thumbsy
  module Api
    class Configuration
      attr_accessor :require_authentication, :authentication_method, :current_voter_method, :require_authorization,
                    :authorization_method, :voter_serializer

      def initialize
        @require_authentication = true
        @require_authorization = false
        @authentication_method = nil
        @current_voter_method = nil
        @authorization_method = nil
        @voter_serializer = nil
      end
    end
  end
end
