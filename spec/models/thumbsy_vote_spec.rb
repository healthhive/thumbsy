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
    ThumbsyVote.setup_feedback_options_validation! if defined?(ThumbsyVote)
  end

  let!(:user) { ThumbsyVoteModelUser.create!(name: "Model User") }
  let!(:book) { ThumbsyVoteModelBook.create!(title: "Model Book") }

  describe "validations" do
    it "is valid with valid feedback_options" do
      vote = ThumbsyVote.new(votable: book, voter: user, vote: true, feedback_options: ["like"])
      expect(vote).to be_valid
      expect(vote.feedback_options).to eq(["like"])
    end

    it "is invalid with invalid feedback_options" do
      vote = ThumbsyVote.new(votable: book, voter: user, vote: true, feedback_options: ["invalid_option"])
      expect(vote.save).to be false
      expect(vote.errors[:feedback_options]).to include("contains invalid feedback option(s)")
    end

    it "raises on create! with invalid feedback_options" do
      expect do
        ThumbsyVote.create!(votable: book, voter: user, vote: true, feedback_options: ["invalid_option"])
      end.to raise_error(ActiveRecord::RecordInvalid, /Feedback options contains invalid feedback option/)
    end

    it "allows feedback_options to be nil or empty" do
      vote = ThumbsyVote.new(votable: book, voter: user, vote: true, feedback_options: nil)
      expect(vote).to be_valid
      expect(vote.feedback_options).to eq([])
      vote2 = ThumbsyVote.new(votable: book, voter: user, vote: true, feedback_options: [])
      expect(vote2).to be_valid
      expect(vote2.feedback_options).to eq([])
    end

    it "enforces uniqueness of voter per votable" do
      ThumbsyVote.create!(votable: book, voter: user, vote: true, feedback_options: ["like"])
      dup_vote = ThumbsyVote.new(votable: book, voter: user, vote: false, feedback_options: ["dislike"])
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
      vote = ThumbsyVote.vote_for(book, user, true, comment: "First", feedback_options: ["like"])
      expect(vote).to be_persisted
      expect(vote.vote).to be true
      expect(vote.comment).to eq("First")
      expect(vote.feedback_options).to eq(["like"])
    end

    it "updates an existing vote for the same voter/votable" do
      vote1 = ThumbsyVote.vote_for(book, user, true, comment: "First", feedback_options: ["like"])
      vote2 = ThumbsyVote.vote_for(book, user, false, comment: "Changed", feedback_options: ["dislike"])
      expect(vote2.id).to eq(vote1.id)
      expect(vote2.vote).to be false
      expect(vote2.comment).to eq("Changed")
      expect(vote2.feedback_options).to eq(["dislike"])
    end
  end

  describe "votable interface error reporting" do
    it "returns a vote with errors when invalid feedback_options are given" do
      vote = book.vote_up(user, feedback_options: ["invalid_option"])
      expect(vote).to be_a(ThumbsyVote)
      expect(vote.errors[:feedback_options]).to include("contains invalid feedback option(s)")
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
  end
end
