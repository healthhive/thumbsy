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

    def vote_up(voter, comment: nil, feedback_option: nil)
      return false if voter && !voter.respond_to?(:thumbsy_votes)

      ThumbsyVote.vote_for(self, voter, true, comment: comment, feedback_option: feedback_option)
    rescue ActiveRecord::RecordInvalid
      false
    rescue ArgumentError => e
      # Only catch ArgumentError for invalid feedback options, not for nil voters/votables
      raise e unless e.message.include?("is not a valid feedback_option")

      false
    end

    def vote_down(voter, comment: nil, feedback_option: nil)
      return false if voter && !voter.respond_to?(:thumbsy_votes)

      ThumbsyVote.vote_for(self, voter, false, comment: comment, feedback_option: feedback_option)
    rescue ActiveRecord::RecordInvalid
      false
    rescue ArgumentError => e
      # Only catch ArgumentError for invalid feedback options, not for nil voters/votables
      raise e unless e.message.include?("is not a valid feedback_option")

      false
    end

    # rubocop:disable Naming/PredicateMethod
    def remove_vote(voter)
      destroyed = thumbsy_votes.where(voter: voter).destroy_all
      destroyed.any?
    end
    # rubocop:enable Naming/PredicateMethod

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
