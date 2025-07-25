# frozen_string_literal: true

require "spec_helper"
require "action_controller"
require "action_controller/api"
require "thumbsy/api"
require "thumbsy/api/controllers/application_controller"
require "thumbsy/api/controllers/votes_controller"
require "thumbsy/api/serializers/vote_serializer"

class User < ActiveRecord::Base
  voter
end

class Book < ActiveRecord::Base
  votable
end

# Test models for controller specs
class InvalidVotable < ActiveRecord::Base
  # No votable concern included
end

RSpec.describe Thumbsy::Api::VotesController do
  let!(:user) { User.create!(name: "Controller User") }
  let!(:book) { Book.create!(title: "Controller Book") }
  let(:invalid_votable) { InvalidVotable.create!(name: "Invalid") }
  let(:controller) { described_class.new }

  before(:each) do
    # Setup feedback options and reload model
    Thumbsy.feedback_options = %w[like dislike funny]
    Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
    load "lib/thumbsy/models/thumbsy_vote.rb"

    # Reset configuration before each test
    Thumbsy::Api.configure do |config|
      config.require_authentication = false
      config.require_authorization = false
      config.authentication_method = nil
      config.current_voter_method = -> { user }
      config.authorization_method = nil
      config.voter_serializer = nil
    end

    # Mock the controller instance variables and methods
    allow(controller).to receive(:current_voter).and_return(user)
    allow(controller).to receive(:render_success)
    allow(controller).to receive(:render_error)
    allow(controller).to receive(:params).and_return(ActionController::Parameters.new({}))
  end

  # ============================================================================
  # BASIC FUNCTIONALITY TESTS
  # ============================================================================

  describe "#vote_up" do
    before do
      allow(controller).to receive(:find_votable)
      controller.instance_variable_set(:@votable, book)
    end

    it "creates an up vote successfully" do
      allow(controller).to receive(:vote_params).and_return({
                                                              comment: "Great book!",
                                                              feedback_options: ["like"],
                                                            })

      expect(controller).to receive(:render_success).with(
        hash_including(
          vote_type: "up",
          comment: "Great book!",
          feedback_options: ["like"],
        ),
        :created,
      )

      controller.vote_up
    end

    it "handles failed vote creation" do
      # Use a real invalid vote instance
      vote = ThumbsyVote.new # Not persisted, missing required fields
      allow(book).to receive(:vote_up).and_return(vote)
      expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote", anything)
      controller.vote_up
    end

    it "handles vote with validation errors" do
      # Use a real invalid vote instance
      vote = ThumbsyVote.new # Not persisted, missing required fields
      allow(book).to receive(:vote_up).and_return(vote)
      expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote", anything)
      controller.send(:vote_up)
    end
  end

  describe "#vote_down" do
    before do
      allow(controller).to receive(:find_votable)
      controller.instance_variable_set(:@votable, book)
    end

    it "creates a down vote successfully" do
      allow(controller).to receive(:vote_params).and_return({
                                                              comment: "Not my cup of tea",
                                                              feedback_options: ["dislike"],
                                                            })

      expect(controller).to receive(:render_success).with(
        hash_including(
          vote_type: "down",
          comment: "Not my cup of tea",
          feedback_options: ["dislike"],
        ),
        :created,
      )

      controller.vote_down
    end

    it "handles failed vote creation" do
      # Use a real invalid vote instance
      vote = ThumbsyVote.new # Not persisted, missing required fields
      allow(book).to receive(:vote_down).and_return(vote)
      expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote", anything)
      controller.send(:vote_down)
    end
  end

  describe "#remove" do
    before do
      allow(controller).to receive(:find_votable)
      controller.instance_variable_set(:@votable, book)
    end

    it "removes a vote successfully" do
      allow(book).to receive(:remove_vote).and_return(true)

      expect(controller).to receive(:render_success).with(
        { message: "Vote removed" },
      )

      controller.remove
    end

    it "handles when no vote exists" do
      allow(book).to receive(:remove_vote).and_return(false)

      expect(controller).to receive(:render_not_found).with(nil)

      controller.remove
    end
  end

  describe "#status" do
    let(:vote) { book.vote_up(user, comment: "Test vote", feedback_options: ["like"]) }

    before do
      allow(controller).to receive(:find_votable)
      controller.instance_variable_set(:@votable, book)
    end

    it "returns vote status with vote data" do
      vote # Create the vote

      expect(controller).to receive(:render_success).with(
        hash_including(
          voted: true,
          vote_type: "up",
          comment: "Test vote",
          vote_counts: hash_including(
            total: 1,
            up: 1,
            down: 0,
            score: 1,
          ),
        ),
      )

      controller.status
    end

    it "returns status for no vote" do
      expect(controller).to receive(:render_success).with(
        hash_including(
          voted: false,
          vote_type: nil,
          vote_counts: hash_including(
            total: 0,
            up: 0,
            down: 0,
            score: 0,
          ),
        ),
      )

      controller.status
    end
  end

  describe "#index" do
    before do
      allow(controller).to receive(:find_votable)
      controller.instance_variable_set(:@votable, book)
      book.vote_up(user, comment: "First vote", feedback_options: ["like"])
      book.vote_up(User.create!(name: "Another User"), comment: "Second vote", feedback_options: ["dislike"])
    end

    it "returns all votes" do
      expect(controller).to receive(:render_success).with(
        hash_including(
          votes: array_including(
            hash_including(vote_type: "up"),
            hash_including(vote_type: "up"),
          ),
          summary: hash_including(
            total: 2,
            up: 2,
            down: 0,
          ),
        ),
      )

      controller.index
    end

    it "filters votes by type" do
      allow(controller).to receive(:params).and_return({ vote_type: "up" })

      expect(controller).to receive(:render_success).with(
        hash_including(
          votes: array_including(
            hash_including(vote_type: "up"),
          ),
          summary: hash_including(
            total: 2,
            up: 2,
            down: 0,
          ),
        ),
      )

      controller.index
    end
  end

  describe "#show" do
    before do
      allow(controller).to receive(:find_votable)
      controller.instance_variable_set(:@votable, book)
    end

    it "returns the current user's vote details if a vote exists" do
      vote = book.vote_up(user, comment: "Show test", feedback_options: ["like"])
      expect(controller).to receive(:render_success).with(
        hash_including(
          id: vote.id,
          vote_type: "up",
          comment: "Show test",
          feedback_options: ["like"],
          voter: hash_including(id: user.id, type: "User"),
        ),
      )
      controller.show
    end

    it "returns not found if the user has not voted" do
      expect(controller).to receive(:render_not_found).with(nil)
      controller.show
    end
  end

  # ============================================================================
  # INTEGRATION FLOW TESTS
  # ============================================================================

  describe "Integration Flow Tests" do
    before do
      # Ensure model is loaded with correct feedback options
      Thumbsy.feedback_options = %w[like dislike funny]
      Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"

      allow(controller).to receive(:find_votable)
      controller.instance_variable_set(:@votable, book)
    end

    it "votes up and then retrieves the vote via GET" do
      # Step 1: Create an up vote via vote_up action
      allow(controller).to receive(:vote_params).and_return({
                                                              comment: "Great book!",
                                                              feedback_options: ["like"],
                                                            })

      # Mock render methods to capture response data
      response_data = nil
      allow(controller).to receive(:render_success) { |data, status| response_data = { data: data, status: status } }

      controller.vote_up

      expect(response_data[:status]).to eq(:created)
      expect(response_data[:data][:vote_type]).to eq("up")
      expect(response_data[:data][:comment]).to eq("Great book!")
      expect(response_data[:data][:feedback_options]).to eq(["like"])

      # Step 2: Verify the vote was created in the database
      expect(book.voted_by?(user)).to be true
      expect(book.votes_count).to eq(1)
      expect(book.up_votes_count).to eq(1)

      # Step 3: Retrieve the vote via index action
      allow(controller).to receive(:vote_params).and_return({})

      controller.index

      expect(response_data[:data][:summary][:total]).to eq(1)
      expect(response_data[:data][:summary][:up]).to eq(1)
      expect(response_data[:data][:summary][:down]).to eq(0)
      expect(response_data[:data][:votes]).to be_an(Array)
      expect(response_data[:data][:votes].length).to eq(1)

      # Step 4: Verify the vote details in the response
      vote_data = response_data[:data][:votes].first
      expect(vote_data[:comment]).to eq("Great book!")
      expect(vote_data[:feedback_options]).to eq(["like"])
      expect(vote_data[:vote_type]).to eq("up")
      expect(vote_data[:voter][:id]).to eq(user.id)
      expect(vote_data[:voter][:type]).to eq("User")
    end

    it "votes down and then retrieves the vote via GET" do
      # Step 1: Create a down vote
      allow(controller).to receive(:vote_params).and_return({
                                                              comment: "Not my style",
                                                              feedback_options: ["dislike"],
                                                            })

      response_data = nil
      allow(controller).to receive(:render_success) { |data, status| response_data = { data: data, status: status } }

      controller.vote_down

      expect(response_data[:status]).to eq(:created)
      expect(response_data[:data][:vote_type]).to eq("down")

      # Step 2: Retrieve the vote
      allow(controller).to receive(:vote_params).and_return({})

      controller.index

      expect(response_data[:data][:summary][:total]).to eq(1)
      expect(response_data[:data][:summary][:up]).to eq(0)
      expect(response_data[:data][:summary][:down]).to eq(1)

      vote_data = response_data[:data][:votes].first
      expect(vote_data[:comment]).to eq("Not my style")
      expect(vote_data[:feedback_options]).to eq(["dislike"])
      expect(vote_data[:vote_type]).to eq("down")
    end

    it "retrieves vote status for a specific user" do
      # Step 1: Create a vote
      allow(controller).to receive(:vote_params).and_return({
                                                              comment: "Excellent!",
                                                            })

      response_data = nil
      allow(controller).to receive(:render_success) { |data, status| response_data = { data: data, status: status } }

      controller.vote_up

      # Step 2: Get the vote status
      controller.status

      expect(response_data[:data][:voted]).to be true
      expect(response_data[:data][:vote_type]).to eq("up")
      expect(response_data[:data][:comment]).to eq("Excellent!")
      expect(response_data[:data][:vote_counts][:total]).to eq(1)
      expect(response_data[:data][:vote_counts][:up]).to eq(1)
      expect(response_data[:data][:vote_counts][:down]).to eq(0)
    end

    it "removes a vote via DELETE" do
      # Step 1: Create a vote first
      allow(controller).to receive(:vote_params).and_return({ comment: "Great!" })

      response_data = nil
      allow(controller).to receive(:render_success) { |data, status| response_data = { data: data, status: status } }

      controller.vote_up

      expect(book.voted_by?(user)).to be true

      # Step 2: Remove the vote (don't mock, let it actually remove)
      controller.remove

      expect(response_data[:data][:message]).to eq("Vote removed")

      # Step 3: Verify the vote is gone
      expect(book.voted_by?(user)).to be false
      expect(book.votes_count).to eq(0)
    end
  end

  # ============================================================================
  # ERROR HANDLING AND EDGE CASES
  # ============================================================================

  describe "Error Handling and Edge Cases" do
    describe "find_votable method" do
      it "handles invalid votable type gracefully" do
        allow(controller).to receive(:params).and_return({
                                                           votable_type: "NonExistentClass",
                                                           votable_id: "1",
                                                         })

        expect(controller).to receive(:render_error).with("Invalid votable type", :bad_request)
        controller.send(:find_votable)
      end

      it "handles missing votable gracefully" do
        allow(controller).to receive(:params).and_return({
                                                           votable_type: "Book",
                                                           votable_id: "999999",
                                                         })

        expect(controller).to receive(:render_error).with("Resource not found", :not_found)
        controller.send(:find_votable)
      end

      it "finds valid votable successfully" do
        allow(controller).to receive(:params).and_return({
                                                           votable_type: "Book",
                                                           votable_id: book.id.to_s,
                                                         })

        controller.send(:find_votable)
        expect(controller.instance_variable_get(:@votable)).to eq(book)
      end
    end

    describe "check_votable_permissions method" do
      before(:each) do
        controller.instance_variable_set(:@votable, book)
        allow(controller).to receive(:current_voter).and_return(user)
      end

      it "skips authorization when not required" do
        Thumbsy::Api.configure { |config| config.require_authorization = false }

        expect(controller).not_to receive(:render_error)
        controller.send(:check_votable_permissions)
      end

      it "executes authorization method when required" do
        authorized = false
        test_user = user
        Thumbsy::Api.configure do |config|
          config.require_authorization = true
          config.authorization_method = lambda do |votable, voter|
            authorized = true
            votable.title == "Controller Book" && voter == test_user
          end
        end

        controller.send(:check_votable_permissions)
        expect(authorized).to be true
      end

      it "renders error when authorization fails" do
        Thumbsy::Api.configure do |config|
          config.require_authorization = true
          config.authorization_method = ->(_votable, _voter) { false }
        end

        expect(controller).to receive(:render_error).with("Access denied", :forbidden)
        controller.send(:check_votable_permissions)
      end

      it "allows access when authorization succeeds" do
        Thumbsy::Api.configure do |config|
          config.require_authorization = true
          config.authorization_method = ->(_votable, _voter) { true }
        end

        expect(controller).not_to receive(:render_error)
        controller.send(:check_votable_permissions)
      end
    end

    describe "vote_params method" do
      it "handles vote parameters correctly" do
        allow(controller).to receive(:params).and_return(
          ActionController::Parameters.new({
                                             comment: "Great book!",
                                             feedback_options: ["like"],
                                             votable_type: "Book",
                                             votable_id: "1",
                                           }),
        )

        result = controller.send(:vote_params)
        expect(result[:comment]).to eq("Great book!")
        expect(result[:feedback_options]).to eq(["like"])
        expect(result[:votable_type]).to eq("Book")
        expect(result[:votable_id]).to eq("1")
      end

      it "handles missing parameters gracefully" do
        params = ActionController::Parameters.new({
                                                    votable_type: "Book",
                                                    votable_id: book.id,
                                                  })

        allow(controller).to receive(:params).and_return(params)

        result = controller.send(:vote_params)
        expect(result[:comment]).to be_nil
        expect(result[:feedback_options]).to be_nil
        expect(result[:votable_type]).to eq("Book")
        expect(result[:votable_id]).to eq(book.id)
      end
    end
  end

  # ============================================================================
  # SERIALIZER INTEGRATION TESTS
  # ============================================================================

  describe "Serializer Integration" do
    before do
      # Ensure model is loaded with correct feedback options
      Thumbsy.feedback_options = %w[like dislike funny]
      Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"

      allow(controller).to receive(:find_votable)
      controller.instance_variable_set(:@votable, book)
    end

    it "uses VoteSerializer for vote responses" do
      allow(controller).to receive(:vote_params).and_return({
                                                              comment: "Amazing book!",
                                                              feedback_options: ["like"],
                                                            })

      response_data = nil
      allow(controller).to receive(:render_success) { |data, status| response_data = { data: data, status: status } }

      controller.vote_up

      expect(response_data[:status]).to eq(:created)
      expect(response_data[:data]).to include(
        id: be_a(Integer),
        vote_type: "up",
        comment: "Amazing book!",
        feedback_options: ["like"],
        voter: hash_including(
          id: user.id,
          type: "User",
        ),
      )
      # Serializer doesn't include timestamps
      expect(response_data[:data]).not_to include(:created_at, :updated_at)
    end

    it "includes voter data in vote response" do
      allow(controller).to receive(:vote_params).and_return({
                                                              comment: "Great book!",
                                                            })

      response_data = nil
      allow(controller).to receive(:render_success) { |data, status| response_data = { data: data, status: status } }

      controller.vote_up

      expect(response_data[:data][:voter]).to include(
        id: user.id,
        type: "User",
      )
    end

    it "uses VoteSerializer for index responses" do
      book.vote_up(user, comment: "Test vote", feedback_options: ["like"])

      response_data = nil
      allow(controller).to receive(:render_success) { |data, status| response_data = { data: data, status: status } }

      controller.index

      expect(response_data[:data][:votes]).to be_an(Array)
      expect(response_data[:data][:votes].length).to eq(1)

      vote_data = response_data[:data][:votes].first
      expect(vote_data).to include(
        id: be_a(Integer),
        vote_type: "up",
        comment: "Test vote",
        feedback_options: ["like"],
        voter: hash_including(
          id: user.id,
          type: "User",
        ),
      )
      # Serializer doesn't include timestamps
      expect(vote_data).not_to include(:created_at, :updated_at)
    end
  end
end
