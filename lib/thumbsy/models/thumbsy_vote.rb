# frozen_string_literal: true

require "active_record"
require_relative "../validators/array_inclusion_validator"

class ThumbsyVote < ActiveRecord::Base
  serialize :feedback_options

  after_initialize :set_default_feedback_options

  def feedback_options=(value)
    super(value.nil? ? [] : value)
  end

  # Dynamically (re)setup feedback_options validation
  def self.setup_feedback_options_validation!
    return unless Thumbsy.feedback_options.present?

    _validators.delete(:feedback_options)
    validates :feedback_options, array_inclusion: { in: Thumbsy.feedback_options }, allow_nil: false
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

  def self.vote_for(votable, voter, vote_value, comment: nil, feedback_options: nil)
    raise ArgumentError, "Voter cannot be nil" if voter.nil?
    raise ArgumentError, "Votable cannot be nil" if votable.nil?

    existing_vote = find_by(
      votable: votable,
      voter: voter,
    )

    if existing_vote
      existing_vote.update!(
        vote: vote_value,
        comment: comment,
        feedback_options: feedback_options,
      )
      existing_vote
    else
      create!(
        votable: votable,
        voter: voter,
        vote: vote_value,
        comment: comment,
        feedback_options: feedback_options,
      )
    end
  end

  private

  def set_default_feedback_options
    self.feedback_options = [] if feedback_options.nil?
  end
end
