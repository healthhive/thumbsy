# frozen_string_literal: true

class ThumbsyVote < ActiveRecord::Base
  belongs_to :votable, polymorphic: true
  belongs_to :voter, polymorphic: true

  validates :votable, presence: true
  validates :voter, presence: true
  validates :vote, inclusion: { in: [true, false] }
  validates :voter_id, uniqueness: { scope: %i[voter_type votable_type votable_id] }

  scope :up_votes, -> { where(vote: true) }
  scope :down_votes, -> { where(vote: false) }
  scope :with_comments, -> { where.not(comment: [nil, ""]) }

  def up_vote?
    vote == true
  end

  def down_vote?
    vote == false
  end
end
