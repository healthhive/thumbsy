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

RSpec.describe "Thumbsy API Controller Methods" do
  let!(:user) { User.create!(name: "Test User") }
  let!(:book) { Book.create!(title: "Test Book") }
  let(:controller) { Thumbsy::Api::VotesController.new }

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
    allow(controller).to receive(:find_votable)
    controller.instance_variable_set(:@votable, book)

    # Mock the serializer more specifically
    allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(
      double("serializer", as_json: { vote_type: "up", comment: "test" }),
    )
  end

  describe "#vote_up" do
    it "creates a vote with feedback option" do
      allow(controller).to receive(:vote_params).and_return(
        ActionController::Parameters.new({
                                           comment: "Great book!",
                                           feedback_option: "like",
                                         }),
      )

      # Mock the serializer to avoid the missing constant error
      serializer_double = double("serializer",
                                 as_json: { vote_type: "up", comment: "Great book!", feedback_option: "like" })
      allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

      expect(controller).to receive(:render_success).with(
        { vote_type: "up", comment: "Great book!", feedback_option: "like" },
        :created,
      )

      controller.vote_up
    end

    it "rejects invalid feedback options" do
      allow(controller).to receive(:vote_params).and_return(
        ActionController::Parameters.new({
                                           feedback_option: "invalid",
                                         }),
      )

      # The controller should handle the ArgumentError and render an error
      expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote")

      controller.vote_up
    end

    it "creates a vote without feedback option" do
      allow(controller).to receive(:vote_params).and_return(
        ActionController::Parameters.new({
                                           comment: "Amazing book!",
                                         }),
      )

      # Mock the serializer to avoid the missing constant error
      serializer_double = double("serializer", as_json: { vote_type: "up", comment: "Amazing book!" })
      allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

      expect(controller).to receive(:render_success).with(
        { vote_type: "up", comment: "Amazing book!" },
        :created,
      )

      controller.vote_up
    end
  end

  describe "#vote_down" do
    it "creates a down vote with feedback option" do
      allow(controller).to receive(:vote_params).and_return(
        ActionController::Parameters.new({
                                           comment: "Not my style",
                                           feedback_option: "dislike",
                                         }),
      )

      # Mock the serializer to avoid the missing constant error
      serializer_double = double("serializer",
                                 as_json: { vote_type: "down", comment: "Not my style", feedback_option: "dislike" })
      allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

      expect(controller).to receive(:render_success).with(
        { vote_type: "down", comment: "Not my style", feedback_option: "dislike" },
        :created,
      )

      controller.vote_down
    end

    it "rejects invalid feedback options for down vote" do
      allow(controller).to receive(:vote_params).and_return(
        ActionController::Parameters.new({
                                           feedback_option: "invalid_option",
                                         }),
      )

      # The controller should handle the ArgumentError and render an error
      expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote")

      controller.vote_down
    end
  end

  describe "#status" do
    it "returns vote status when user has voted" do
      # First create a vote
      book.vote_up(user, comment: "Great book!", feedback_option: "like")

      expect(controller).to receive(:render_success).with(
        {
          voted: true,
          vote_type: "up",
          comment: "Great book!",
          vote_counts: { up: 1, down: 0, total: 1, score: 1 },
        },
      )

      controller.status
    end

    it "returns no vote when user has not voted" do
      expect(controller).to receive(:render_success).with(
        {
          voted: false,
          vote_type: nil,
          comment: nil,
          vote_counts: { up: 0, down: 0, total: 0, score: 0 },
        },
      )

      controller.status
    end
  end

  describe "#remove" do
    it "removes existing vote" do
      # First create a vote
      book.vote_up(user, comment: "Great book!")

      expect(controller).to receive(:render_success).with(
        { message: "Vote removed" },
      )

      controller.remove
      expect(book.voted_by?(user)).to be false
    end

    it "handles removing non-existent vote gracefully" do
      expect(controller).to receive(:render_not_found).with(nil)

      controller.remove
    end
  end

  describe "#index" do
    it "returns all votes for the votable" do
      # Create multiple votes
      user2 = User.create!(name: "Another User")
      book.vote_up(user, comment: "Great book!", feedback_option: "like")
      book.vote_down(user2, comment: "Not my style", feedback_option: "dislike")

      # Mock the serializer to avoid the missing constant error
      serializer_double = double("serializer", as_json: { vote_type: "up", comment: "Great book!" })
      allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

      expect(controller).to receive(:render_success).with(
        {
          votes: [{ vote_type: "up", comment: "Great book!" }, { vote_type: "up", comment: "Great book!" }],
          summary: { up: 1, down: 1, total: 2, score: 0 },
        },
      )

      controller.index
    end

    it "returns empty array when no votes exist" do
      expect(controller).to receive(:render_success).with(
        {
          votes: [],
          summary: { up: 0, down: 0, total: 0, score: 0 },
        },
      )

      controller.index
    end
  end

  describe "vote_params method" do
    it "handles vote parameters correctly" do
      params = ActionController::Parameters.new({
                                                  comment: "Great book!",
                                                  feedback_option: "like",
                                                })
      allow(controller).to receive(:params).and_return(params)

      result = controller.send(:vote_params)
      expect(result).to be_a(ActionController::Parameters)
      expect(result[:comment]).to eq("Great book!")
      expect(result[:feedback_option]).to eq("like")
    end

    it "handles missing parameters gracefully" do
      params = ActionController::Parameters.new({})
      allow(controller).to receive(:params).and_return(params)

      result = controller.send(:vote_params)
      expect(result).to be_a(ActionController::Parameters)
      expect(result.to_h).to eq({})
    end
  end

  describe "find_votable method" do
    it "finds valid votable" do
      params = ActionController::Parameters.new({
                                                  votable_type: "Book",
                                                  votable_id: book.id.to_s,
                                                })
      allow(controller).to receive(:params).and_return(params)

      result = controller.send(:find_votable)
      expect(result).to be_nil # find_votable sets @votable but returns nil
      expect(controller.instance_variable_get(:@votable)).to eq(book)
    end
  end

  describe "Feedback Option Validation" do
    before(:each) do
      # Ensure model is loaded with correct feedback options
      Thumbsy.feedback_options = %w[like dislike funny]
      Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"
    end

    describe "#vote_up with feedback options" do
      it "accepts valid feedback options" do
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: "like",
                                           }),
        )

        serializer_double = double("serializer", as_json: { vote_type: "up", feedback_option: "like" })
        allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

        expect(controller).to receive(:render_success).with(
          { vote_type: "up", feedback_option: "like" },
          :created,
        )

        controller.vote_up
      end

      it "accepts nil feedback option" do
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: nil,
                                           }),
        )

        serializer_double = double("serializer", as_json: { vote_type: "up", feedback_option: nil })
        allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

        expect(controller).to receive(:render_success).with(
          { vote_type: "up", feedback_option: nil },
          :created,
        )

        controller.vote_up
      end

      it "rejects invalid feedback options" do
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: "invalid_option",
                                           }),
        )

        expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote")

        controller.vote_up
      end

      it "accepts empty string feedback option (converts to nil)" do
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: "",
                                           }),
        )

        # Empty strings are converted to nil by the enum
        serializer_double = double("serializer", as_json: { vote_type: "up", feedback_option: nil })
        allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

        expect(controller).to receive(:render_success).with(
          { vote_type: "up", feedback_option: nil },
          :created,
        )

        controller.vote_up
      end

      it "rejects multiple invalid feedback options" do
        invalid_options = %w[spam fake bogus invalid_option]

        invalid_options.each do |invalid_option|
          allow(controller).to receive(:vote_params).and_return(
            ActionController::Parameters.new({
                                               feedback_option: invalid_option,
                                             }),
          )

          expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote")

          controller.vote_up
        end
      end
    end

    describe "#vote_down with feedback options" do
      it "accepts valid feedback options" do
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: "dislike",
                                           }),
        )

        serializer_double = double("serializer", as_json: { vote_type: "down", feedback_option: "dislike" })
        allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

        expect(controller).to receive(:render_success).with(
          { vote_type: "down", feedback_option: "dislike" },
          :created,
        )

        controller.vote_down
      end

      it "accepts nil feedback option" do
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: nil,
                                           }),
        )

        serializer_double = double("serializer", as_json: { vote_type: "down", feedback_option: nil })
        allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

        expect(controller).to receive(:render_success).with(
          { vote_type: "down", feedback_option: nil },
          :created,
        )

        controller.vote_down
      end

      it "rejects invalid feedback options" do
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: "invalid_option",
                                           }),
        )

        expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote")

        controller.vote_down
      end
    end

    describe "comprehensive feedback option scenarios" do
      it "handles all valid feedback options" do
        valid_options = %w[like dislike funny]

        valid_options.each do |valid_option|
          allow(controller).to receive(:vote_params).and_return(
            ActionController::Parameters.new({
                                               feedback_option: valid_option,
                                             }),
          )

          serializer_double = double("serializer", as_json: { vote_type: "up", feedback_option: valid_option })
          allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

          expect(controller).to receive(:render_success).with(
            { vote_type: "up", feedback_option: valid_option },
            :created,
          )

          controller.vote_up
        end
      end

      it "handles mixed valid and invalid feedback options" do
        # Test valid option
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: "like",
                                           }),
        )

        serializer_double = double("serializer", as_json: { vote_type: "up", feedback_option: "like" })
        allow(Thumbsy::Api::Serializers::VoteSerializer).to receive(:new).and_return(serializer_double)

        expect(controller).to receive(:render_success).with(
          { vote_type: "up", feedback_option: "like" },
          :created,
        )

        controller.vote_up

        # Test invalid option
        allow(controller).to receive(:vote_params).and_return(
          ActionController::Parameters.new({
                                             feedback_option: "invalid_option",
                                           }),
        )

        expect(controller).to receive(:render_unprocessable_entity).with("Failed to create vote")

        controller.vote_up
      end
    end
  end
end
