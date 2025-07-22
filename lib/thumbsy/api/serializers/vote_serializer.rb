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
            feedback_option: serialize_feedback_option,
            voter: voter_data(@vote.voter),
          }
        end

        private

        def serialize_feedback_option
          feedback_option = @vote.feedback_option
          return feedback_option if feedback_option.is_a?(String) || feedback_option.nil?

          # If it's an integer (corrupted enum), use the global feedback options
          feedback_options = Thumbsy.feedback_options
          return nil unless feedback_options&.is_a?(Array)

          feedback_options[feedback_option] if feedback_option < feedback_options.length
        end

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
