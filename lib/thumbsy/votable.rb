# frozen_string_literal: true

module Thumbsy
  module Votable
    extend ActiveSupport::Concern

    included do
      has_many :thumbsy_votes, as: :votable, class_name: "ThumbsyVote", dependent: :destroy
      scope :with_votes, -> { joins(:thumbsy_votes) }
      scope :with_up_votes, -> { joins(:thumbsy_votes).where(thumbsy_votes: { vote: true }) }
      scope :with_down_votes, -> { joins(:thumbsy_votes).where(thumbsy_votes: { vote: false }) }
      scope :with_comments, -> { joins(:thumbsy_votes).where.not(thumbsy_votes: { comment: [nil, ""] }) }
    end

    def vote_up(voter, comment: nil)
      vote_for(voter, true, comment: comment)
    end

    def vote_down(voter, comment: nil)
      vote_for(voter, false, comment: comment)
    end

    def vote_for(voter, vote_value, comment: nil)
      return false unless voter.respond_to?(:thumbsy_votes)

      existing_vote = thumbsy_votes.find_by(voter: voter)
      if existing_vote
        existing_vote.update(vote: vote_value, comment: comment)
        existing_vote
      else
        thumbsy_votes.create(voter: voter, vote: vote_value, comment: comment)
      end
    end

    def remove_vote(voter)
      thumbsy_votes.where(voter: voter).destroy_all
    end

    def voted_by?(voter)
      thumbsy_votes.exists?(voter: voter)
    end

    def up_voted_by?(voter)
      thumbsy_votes.exists?(voter: voter, vote: true)
    end

    def down_voted_by?(voter)
      thumbsy_votes.exists?(voter: voter, vote: false)
    end

    def vote_by(voter)
      thumbsy_votes.find_by(voter: voter)
    end

    def votes_count
      thumbsy_votes.count
    end

    def up_votes_count
      thumbsy_votes.where(vote: true).count
    end

    def down_votes_count
      thumbsy_votes.where(vote: false).count
    end

    def votes_score
      up_votes_count - down_votes_count
    end

    def votes_with_comments
      thumbsy_votes.where.not(comment: [nil, ""])
    end

    def up_votes_with_comments
      thumbsy_votes.where(vote: true).where.not(comment: [nil, ""])
    end

    def down_votes_with_comments
      thumbsy_votes.where(vote: false).where.not(comment: [nil, ""])
    end
  end
end
