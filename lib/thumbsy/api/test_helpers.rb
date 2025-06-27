# frozen_string_literal: true

module Thumbsy
  module Api
    module TestHelpers
      def vote_up(votable, voter, params = {})
        post "/#{votable.class.name.downcase.pluralize}/#{votable.id}/vote_up",
             params: params.to_json,
             headers: api_headers(voter)
        JSON.parse(response.body)
      end

      def vote_down(votable, voter, params = {})
        post "/#{votable.class.name.downcase.pluralize}/#{votable.id}/vote_down",
             params: params.to_json,
             headers: api_headers(voter)
        JSON.parse(response.body)
      end

      def remove_vote(votable, voter)
        delete "/#{votable.class.name.downcase.pluralize}/#{votable.id}/vote",
               headers: api_headers(voter)
        JSON.parse(response.body)
      end

      def vote_status(votable, voter)
        get "/#{votable.class.name.downcase.pluralize}/#{votable.id}/vote",
            headers: api_headers(voter)
        JSON.parse(response.body)
      end

      def votes_list(votable, voter, params = {})
        get "/#{votable.class.name.downcase.pluralize}/#{votable.id}/votes",
            params: params,
            headers: api_headers(voter)
        JSON.parse(response.body)
      end

      private

      def api_headers(voter = nil)
        headers = { "Content-Type" => "application/json" }
        headers["Authorization"] = "Bearer #{voter.token}" if voter&.token
        headers
      end
    end
  end
end
