# frozen_string_literal: true

module Thumbsy
  module Api
    module Serializers
      class VoteSerializer
        def initialize(vote)
          @vote = vote
        end

        def as_json
          {
            id: @vote.id,
            vote_type: @vote.up_vote? ? "up" : "down",
            comment: @vote.comment,
            feedback_options: @vote.feedback_options || [],
            voter: voter_data(@vote.voter),
          }
        end

        private

        def voter_data(voter)
          if Thumbsy::Api.voter_serializer
            instance_exec(voter, &Thumbsy::Api.voter_serializer)
          else
            {
              id: voter.id,
              type: voter.class.name,
            }
          end
        end
      end
    end
  end
end
