# frozen_string_literal: true

module Thumbsy
  module Voter
    extend ActiveSupport::Concern

    included do
      has_many :thumbsy_votes, as: :voter, class_name: "ThumbsyVote", dependent: :destroy
    end

    def vote_up_for(votable, comment: nil)
      return false unless votable.respond_to?(:thumbsy_votes)

      votable.vote_up(self, comment: comment)
    end

    def vote_down_for(votable, comment: nil)
      return false unless votable.respond_to?(:thumbsy_votes)

      votable.vote_down(self, comment: comment)
    end

    def remove_vote_for(votable)
      return false unless votable.respond_to?(:thumbsy_votes)

      votable.remove_vote(self)
    end

    def voted_for?(votable)
      return false unless votable.respond_to?(:thumbsy_votes)

      votable.voted_by?(self)
    end

    def up_voted_for?(votable)
      return false unless votable.respond_to?(:thumbsy_votes)

      votable.up_voted_by?(self)
    end

    def down_voted_for?(votable)
      return false unless votable.respond_to?(:thumbsy_votes)

      votable.down_voted_by?(self)
    end

    def voted_for(votable_class)
      vote_records = thumbsy_votes.where(votable_type: votable_class.name)
      votable_ids = vote_records.pluck(:votable_id)
      votable_class.where(id: votable_ids)
    end

    def up_voted_for_class(votable_class)
      vote_records = thumbsy_votes.where(votable_type: votable_class.name, vote: true)
      votable_ids = vote_records.pluck(:votable_id)
      votable_class.where(id: votable_ids)
    end

    def down_voted_for_class(votable_class)
      vote_records = thumbsy_votes.where(votable_type: votable_class.name, vote: false)
      votable_ids = vote_records.pluck(:votable_id)
      votable_class.where(id: votable_ids)
    end
  end
end
