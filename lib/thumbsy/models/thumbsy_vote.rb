# frozen_string_literal: true

class ThumbsyVote < ActiveRecord::Base
  # Setup feedback options enum if available
  if (feedback_options = Thumbsy.feedback_options).present?
    enum :feedback_option, feedback_options.each_with_index.to_h
    validates :feedback_option, inclusion: { in: feedback_options }, allow_nil: true
  end

  # Lazy setup of feedback options when they become available
  def self.setup_feedback_options!
    return if Thumbsy.feedback_options.blank?
    return if respond_to?(:feedback_options) # Already set up

    enum :feedback_option, Thumbsy.feedback_options.each_with_index.to_h
    validates :feedback_option, inclusion: { in: Thumbsy.feedback_options }, allow_nil: true
  end

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

  def self.vote_for(votable, voter, vote_value, comment: nil, feedback_option: nil)
    raise ArgumentError, "Voter cannot be nil" if voter.nil?
    raise ArgumentError, "Votable cannot be nil" if votable.nil?

    # Ensure feedback options are set up
    setup_feedback_options!

    existing_vote = find_by(
      votable: votable,
      voter: voter,
    )

    if existing_vote
      existing_vote.update!(
        vote: vote_value,
        comment: comment,
        feedback_option: feedback_option,
      )
      existing_vote
    else
      create!(
        votable: votable,
        voter: voter,
        vote: vote_value,
        comment: comment,
        feedback_option: feedback_option,
      )
    end
  end
end
