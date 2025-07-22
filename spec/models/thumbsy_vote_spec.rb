# frozen_string_literal: true

require "spec_helper"

class ThumbsyVoteModelUser < ActiveRecord::Base
  self.table_name = "users"
  voter
end

class ThumbsyVoteModelBook < ActiveRecord::Base
  self.table_name = "books"
  votable
end

RSpec.describe ThumbsyVote, type: :model do
  before(:all) do
    Thumbsy.feedback_options = %w[like dislike funny]
    Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
    load "lib/thumbsy/models/thumbsy_vote.rb"
  end

  let!(:user) { ThumbsyVoteModelUser.create!(name: "Model User") }
  let!(:book) { ThumbsyVoteModelBook.create!(title: "Model Book") }

  describe "validations" do
    it "is valid with valid feedback_option" do
      vote = ThumbsyVote.new(votable: book, voter: user, vote: true, feedback_option: "like")
      expect(vote).to be_valid
      expect(vote.feedback_option).to eq("like")
    end

    it "is invalid with invalid feedback_option" do
      expect do
        ThumbsyVote.new(votable: book, voter: user, vote: true, feedback_option: "invalid_option")
      end.to raise_error(ArgumentError, /is not a valid feedback_option/)
    end

    it "allows feedback_option to be nil" do
      vote = ThumbsyVote.new(votable: book, voter: user, vote: true, feedback_option: nil)
      expect(vote).to be_valid
      expect(vote.feedback_option).to be_nil
    end

    it "enforces uniqueness of voter per votable" do
      ThumbsyVote.create!(votable: book, voter: user, vote: true, feedback_option: "like")
      dup_vote = ThumbsyVote.new(votable: book, voter: user, vote: false, feedback_option: "dislike")
      expect(dup_vote).not_to be_valid
      expect(dup_vote.errors[:voter_id]).to include("has already been taken")
    end
  end

  describe ".vote_for" do
    it "raises ArgumentError if voter is nil" do
      expect do
        ThumbsyVote.vote_for(book, nil, true)
      end.to raise_error(ArgumentError, "Voter cannot be nil")
    end

    it "raises ArgumentError if votable is nil" do
      expect do
        ThumbsyVote.vote_for(nil, user, true)
      end.to raise_error(ArgumentError, "Votable cannot be nil")
    end

    it "creates a new vote if none exists" do
      vote = ThumbsyVote.vote_for(book, user, true, comment: "First", feedback_option: "like")
      expect(vote).to be_persisted
      expect(vote.vote).to be true
      expect(vote.comment).to eq("First")
      expect(vote.feedback_option).to eq("like")
    end

    it "updates an existing vote for the same voter/votable" do
      vote1 = ThumbsyVote.vote_for(book, user, true, comment: "First", feedback_option: "like")
      vote2 = ThumbsyVote.vote_for(book, user, false, comment: "Changed", feedback_option: "dislike")
      expect(vote2.id).to eq(vote1.id)
      expect(vote2.vote).to be false
      expect(vote2.comment).to eq("Changed")
      expect(vote2.feedback_option).to eq("dislike")
    end
  end

  describe "instance methods" do
    it "returns true for up_vote? when vote is true" do
      vote = ThumbsyVote.new(vote: true)
      expect(vote.up_vote?).to be true
      expect(vote.down_vote?).to be false
    end

    it "returns true for down_vote? when vote is false" do
      vote = ThumbsyVote.new(vote: false)
      expect(vote.down_vote?).to be true
      expect(vote.up_vote?).to be false
    end
  end

  describe "dynamic feedback_options and existing votes" do
    after(:all) do
      Thumbsy.feedback_options = %w[like dislike funny]
      Object.send(:remove_const, :ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"
    end

    it "returns the new first enum value for feedback_option if enum mapping changes (Rails behavior)" do
      # Create a vote with the original feedback_options
      vote = ThumbsyVote.vote_for(book, user, true, comment: "First", feedback_option: "like")
      expect(vote.feedback_option).to eq("like")

      # Change feedback_options to exclude 'like'
      Thumbsy.feedback_options = %w[helpful unhelpful spam]
      Object.send(:remove_const, :ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"

      # Reload the vote from DB (should now have an integer value 0, which maps to 'helpful')
      reloaded_vote = ThumbsyVote.find(vote.id)
      # Rails maps the stored integer to the new enum's first value
      expect(reloaded_vote.feedback_option).to eq("helpful")
      # NOTE: This is a Rails enum gotcha—changing the enum mapping will remap old values to new strings.
    end

    # NOTE: It is not possible to create or update a vote with an old value after the enum mapping changes,
    # as Rails will immediately raise ArgumentError. Only reading is possible, and it will remap to the new enum.
  end
end
