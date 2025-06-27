# frozen_string_literal: true

module Thumbsy
  module Api
    class VotesController < Thumbsy::Api::ApplicationController
      before_action :find_votable
      before_action :check_votable_permissions, if: :authorization_required?

      # POST /votes/vote_up
      def vote_up
        vote = @votable.vote_up(current_voter, comment: vote_params[:comment])

        if vote&.persisted?
          render_success(vote_data(vote), :created)
        else
          render_error("Failed to create vote", :unprocessable_entity)
        end
      end

      # POST /votes/vote_down
      def vote_down
        vote = @votable.vote_down(current_voter, comment: vote_params[:comment])

        if vote&.persisted?
          render_success(vote_data(vote), :created)
        else
          render_error("Failed to create vote", :unprocessable_entity)
        end
      end

      # DELETE /votes/remove
      def remove
        removed = @votable.remove_vote(current_voter)

        if removed
          render_success({ message: "Vote removed" })
        else
          render_error("No vote found to remove", :not_found)
        end
      end

      # GET /votes/status
      def status
        vote = @votable.vote_by(current_voter)

        data = {
          voted: @votable.voted_by?(current_voter),
          vote_type: if vote
                       vote.up_vote? ? "up" : "down"
                     end,
          comment: vote&.comment,
          vote_counts: {
            total: @votable.votes_count,
            up: @votable.up_votes_count,
            down: @votable.down_votes_count,
            score: @votable.votes_score,
          },
        }

        render_success(data)
      end

      # GET /votes
      def index
        votes = filtered_votes
        data = {
          votes: votes.map { |vote| vote_data(vote) },
          summary: vote_summary,
        }

        render_success(data)
      end

      private

      def filtered_votes
        votes = @votable.thumbsy_votes.includes(:voter)
        votes = votes.with_comments if params[:with_comments] == "true"
        votes = votes.up_votes if params[:vote_type] == "up"
        votes = votes.down_votes if params[:vote_type] == "down"
        votes
      end

      def vote_summary
        {
          total: @votable.votes_count,
          up: @votable.up_votes_count,
          down: @votable.down_votes_count,
          score: @votable.votes_score,
        }
      end

      def find_votable
        votable_class = params[:votable_type].constantize
        @votable = votable_class.find(params[:votable_id])
      rescue NameError
        render_error("Invalid votable type", :bad_request)
      end

      def check_votable_permissions
        return unless Thumbsy::Api.authorization_method

        authorized = instance_exec(@votable, current_voter, &Thumbsy::Api.authorization_method)
        render_error("Access denied", :forbidden) unless authorized
      end

      def authorization_required?
        Thumbsy::Api.require_authorization
      end

      def vote_params
        params.permit(:comment, :votable_type, :votable_id)
      end

      def vote_data(vote)
        {
          id: vote.id,
          vote_type: vote.up_vote? ? "up" : "down",
          comment: vote.comment,
          voter: voter_data(vote.voter),
          created_at: vote.created_at,
          updated_at: vote.updated_at,
        }
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
