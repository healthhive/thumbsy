# frozen_string_literal: true

module Thumbsy
  module Api
    class VotesController < Thumbsy::Api::ApplicationController
      before_action :find_votable
      before_action :check_votable_permissions, if: :authorization_required?

      # POST /votes/vote_up
      def vote_up
        vote = @votable.vote_up(current_voter, comment: vote_params[:comment],
                                               feedback_options: vote_params[:feedback_options])

        if vote&.persisted? && vote.errors.empty?
          render_success(Thumbsy::Api::Serializers::VoteSerializer.new(vote).as_json, :created)
        else
          render_unprocessable_entity("Failed to create vote", vote&.errors&.full_messages || [])
        end
      end

      # POST /votes/vote_down
      def vote_down
        vote = @votable.vote_down(current_voter, comment: vote_params[:comment],
                                                 feedback_options: vote_params[:feedback_options])

        if vote&.persisted? && vote.errors.empty?
          render_success(Thumbsy::Api::Serializers::VoteSerializer.new(vote).as_json, :created)
        else
          render_unprocessable_entity("Failed to create vote", vote&.errors&.full_messages || [])
        end
      end

      # DELETE /votes/remove
      def remove
        removed = @votable.remove_vote(current_voter)

        if removed
          render_success({ message: "Vote removed" })
        else
          render_not_found(nil)
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

      # GET /votes/vote
      def show
        vote = @votable.vote_by(current_voter)
        if vote
          render_success(Thumbsy::Api::Serializers::VoteSerializer.new(vote).as_json)
        else
          render_not_found(nil)
        end
      end

      # GET /votes
      def index
        votes = filtered_votes
        data = {
          votes: votes.map { |vote| Thumbsy::Api::Serializers::VoteSerializer.new(vote).as_json },
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
        render_bad_request("Invalid votable type")
      rescue ActiveRecord::RecordNotFound
        render_not_found(nil)
      end

      def check_votable_permissions
        return unless Thumbsy::Api.authorization_method

        authorized = instance_exec(@votable, current_voter, &Thumbsy::Api.authorization_method)
        render_forbidden unless authorized
      end

      def authorization_required?
        Thumbsy::Api.require_authorization
      end

      def vote_params
        permitted = params.permit(:comment, { feedback_options: [] }, :feedback_option, :votable_type, :votable_id)
        # Normalize feedback_option (string) to feedback_options (array)
        if permitted[:feedback_options].blank? && permitted[:feedback_option].present?
          permitted[:feedback_options] = [permitted.delete(:feedback_option)]
        end
        permitted
      end
    end
  end
end
