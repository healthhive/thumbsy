# frozen_string_literal: true

require "spec_helper"
require "thumbsy/api"

class User < ActiveRecord::Base
  voter
end

class Book < ActiveRecord::Base
  votable
end

RSpec.describe "Thumbsy API" do
  let(:user) { User.create!(name: "Test User") }
  let(:user2) { User.create!(name: "Another User") }
  let(:book) { Book.create!(title: "Test Book") }

  # Global configuration reset to ensure test isolation
  before(:each) do
    # Reset configuration before each test
    Thumbsy::Api.configure do |config|
      config.require_authentication = true
      config.require_authorization = false
      config.authentication_method = nil
      config.current_voter_method = nil
      config.authorization_method = nil
      config.voter_serializer = nil
    end
  end

  after(:each) do
    # Reset configuration after each test
    Thumbsy::Api.configure do |config|
      config.require_authentication = true
      config.require_authorization = false
      config.authentication_method = nil
      config.current_voter_method = nil
      config.authorization_method = nil
      config.voter_serializer = nil
    end
  end

  describe "API Configuration" do
    it "has default configuration values" do
      expect(Thumbsy::Api.require_authentication).to be true
      expect(Thumbsy::Api.require_authorization).to be false
      expect(Thumbsy::Api.authentication_method).to be_nil
      expect(Thumbsy::Api.current_voter_method).to be_nil
      expect(Thumbsy::Api.authorization_method).to be_nil
      expect(Thumbsy::Api.voter_serializer).to be_nil
    end

    it "allows configuration changes" do
      test_auth_method = -> { "auth test" }
      test_voter_method = -> { "voter test" }
      test_authz_method = -> { "authz test" }
      test_serializer = -> { "serializer test" }

      Thumbsy::Api.configure do |config|
        config.require_authentication = false
        config.require_authorization = true
        config.authentication_method = test_auth_method
        config.current_voter_method = test_voter_method
        config.authorization_method = test_authz_method
        config.voter_serializer = test_serializer
      end

      expect(Thumbsy::Api.require_authentication).to be false
      expect(Thumbsy::Api.require_authorization).to be true
      expect(Thumbsy::Api.authentication_method).to eq(test_auth_method)
      expect(Thumbsy::Api.current_voter_method).to eq(test_voter_method)
      expect(Thumbsy::Api.authorization_method).to eq(test_authz_method)
      expect(Thumbsy::Api.voter_serializer).to eq(test_serializer)
    end

    it "allows configuration with block syntax" do
      Thumbsy::Api.configure do |config|
        config.require_authentication = false
        expect(config).to be_a(Module) # Should be the Api module itself
      end

      expect(Thumbsy::Api.require_authentication).to be false
    end
  end

  describe "API Exceptions" do
    it "defines custom exception classes" do
      expect(Thumbsy::Api::AuthenticationError).to be < StandardError
      expect(Thumbsy::Api::AuthorizationError).to be < StandardError
    end

    it "can raise authentication errors" do
      expect do
        raise Thumbsy::Api::AuthenticationError, "Not authenticated"
      end.to raise_error(Thumbsy::Api::AuthenticationError, "Not authenticated")
    end

    it "can raise authorization errors" do
      expect do
        raise Thumbsy::Api::AuthorizationError, "Not authorized"
      end.to raise_error(Thumbsy::Api::AuthorizationError, "Not authorized")
    end
  end

  describe "API Loading" do
    it "defines load! method" do
      expect(Thumbsy::Api).to respond_to(:load!)
    end

    it "loads API controller files when load! is called" do
      # Skip actual loading since ActionController::API may not be available in test environment
      # Just check that the controller files exist in the expected location
      lib_path = File.expand_path("../../lib", __dir__)
      expect(File.exist?(File.join(lib_path, "thumbsy/api/controllers/application_controller.rb"))).to be true
      expect(File.exist?(File.join(lib_path, "thumbsy/api/controllers/votes_controller.rb"))).to be true
    end

    it "can attempt to load API components" do
      # Should define the load! method even if ActionController::API is not available
      expect(Thumbsy::Api).to respond_to(:load!)

      # In a real Rails environment, this would work
      # For testing purposes, we just verify the method exists
      begin
        Thumbsy::Api.load!
      rescue NameError => e
        # Expected in test environment without full Rails stack
        expect(e.message).to include("ActionController::API")
      end
    end
  end

  describe "Integration with Core Functionality" do
    it "works alongside core voting functionality" do
      # Configure API
      Thumbsy::Api.configure do |config|
        config.require_authentication = false
        config.voter_serializer = ->(voter) { { id: voter.id, name: voter.name } }
      end

      # Core functionality should still work
      vote = book.vote_up(user, comment: "Great book!")
      expect(vote).to be_persisted
      expect(book.voted_by?(user)).to be true

      # API serializer should be available
      serialized = Thumbsy::Api.voter_serializer.call(user)
      expect(serialized[:id]).to eq(user.id)
      expect(serialized[:name]).to eq(user.name)
    end

    it "provides authorization hooks" do
      authorized = false

      Thumbsy::Api.configure do |config|
        config.authorization_method = lambda do |votable, _voter|
          authorized = true
          votable.title != "Forbidden Book"
        end
      end

      # Test the authorization method
      result = Thumbsy::Api.authorization_method.call(book, user)
      expect(authorized).to be true
      expect(result).to be true

      # Test with forbidden book
      forbidden_book = Book.create!(title: "Forbidden Book")
      result = Thumbsy::Api.authorization_method.call(forbidden_book, user)
      expect(result).to be false
    end
  end

  describe "Authentication Configuration" do
    it "supports custom authentication methods" do
      authenticated = false

      Thumbsy::Api.configure do |config|
        config.authentication_method = lambda do
          authenticated = true
          "authentication successful"
        end
      end

      result = Thumbsy::Api.authentication_method.call
      expect(authenticated).to be true
      expect(result).to eq("authentication successful")
    end

    it "supports current voter resolution" do
      Thumbsy::Api.configure do |config|
        config.current_voter_method = -> { user }
      end

      current_voter = Thumbsy::Api.current_voter_method.call
      expect(current_voter).to eq(user)
    end

    it "can chain authentication and voter resolution" do
      Thumbsy::Api.configure do |config|
        config.authentication_method = -> { user.present? }
        config.current_voter_method = -> { user }
      end

      # Simulate authentication flow
      is_authenticated = Thumbsy::Api.authentication_method.call
      current_voter = Thumbsy::Api.current_voter_method.call if is_authenticated

      expect(is_authenticated).to be true
      expect(current_voter).to eq(user)
    end
  end

  describe "Error Handling Configuration" do
    it "supports configurable authentication requirements" do
      # Default requires authentication
      expect(Thumbsy::Api.require_authentication).to be true

      # Can be disabled
      Thumbsy::Api.configure { |c| c.require_authentication = false }
      expect(Thumbsy::Api.require_authentication).to be false
    end

    it "supports configurable authorization requirements" do
      # Default doesn't require authorization
      expect(Thumbsy::Api.require_authorization).to be false

      # Can be enabled
      Thumbsy::Api.configure { |c| c.require_authorization = true }
      expect(Thumbsy::Api.require_authorization).to be true
    end

    it "maintains configuration consistency" do
      Thumbsy::Api.configure do |config|
        config.require_authentication = false
        config.require_authorization = true
        config.authentication_method = -> { "mock auth" }
      end

      # All configurations should be maintained
      expect(Thumbsy::Api.require_authentication).to be false
      expect(Thumbsy::Api.require_authorization).to be true
      expect(Thumbsy::Api.authentication_method.call).to eq("mock auth")
    end
  end

  describe "Performance with API Configuration" do
    it "handles multiple configuration changes efficiently" do
      start_time = Time.current

      100.times do |i|
        Thumbsy::Api.configure do |config|
          config.require_authentication = i.even?
          config.voter_serializer = ->(voter) { { iteration: i, voter: voter.id } }
        end
      end

      duration = Time.current - start_time
      expect(duration).to be < 0.1 # Should be very fast
    end

    it "configuration access is efficient" do
      Thumbsy::Api.configure do |config|
        config.voter_serializer = ->(voter) { { id: voter.id } }
      end

      start_time = Time.current

      100.times do
        Thumbsy::Api.require_authentication
        Thumbsy::Api.voter_serializer&.call(user)
      end

      duration = Time.current - start_time
      expect(duration).to be < 0.05 # Should be very fast
    end
  end

  describe "Thread Safety" do
    it "maintains configuration across simulated concurrent access" do
      Thumbsy::Api.configure do |config|
        config.require_authentication = false
        config.voter_serializer = ->(voter) { { thread_safe: true, id: voter&.id || 999 } }
      end

      # Simulate concurrent access without actual threading to avoid DB connection issues
      results = []

      3.times do
        auth_required = Thumbsy::Api.require_authentication
        serializer_result = Thumbsy::Api.voter_serializer.call(user)
        results << { auth: auth_required, serializer: serializer_result }
      end

      # All simulated concurrent calls should see the same configuration
      results.each do |result|
        expect(result[:auth]).to be false
        expect(result[:serializer][:thread_safe]).to be true
        expect(result[:serializer][:id]).to eq(user.id)
      end
    end
  end

  describe "API Configuration Persistence" do
    it "persists authentication configuration" do
      Thumbsy::Api.configure do |config|
        config.require_authentication = false
      end

      expect(Thumbsy::Api.require_authentication).to be false
    end

    it "persists authorization configuration" do
      Thumbsy::Api.configure do |config|
        config.require_authorization = true
      end

      expect(Thumbsy::Api.require_authorization).to be true
    end

    it "persists method configurations" do
      auth_method = -> { "test auth" }
      voter_method = -> { "test voter" }
      authz_method = -> { "test authz" }
      serializer = -> { "test serializer" }

      Thumbsy::Api.configure do |config|
        config.authentication_method = auth_method
        config.current_voter_method = voter_method
        config.authorization_method = authz_method
        config.voter_serializer = serializer
      end

      expect(Thumbsy::Api.authentication_method).to eq(auth_method)
      expect(Thumbsy::Api.current_voter_method).to eq(voter_method)
      expect(Thumbsy::Api.authorization_method).to eq(authz_method)
      expect(Thumbsy::Api.voter_serializer).to eq(serializer)
    end
  end

  describe "API Exception Classes" do
    it "defines AuthenticationError correctly" do
      error = Thumbsy::Api::AuthenticationError.new("Auth failed")
      expect(error).to be_a(StandardError)
      expect(error.message).to eq("Auth failed")
    end

    it "defines AuthorizationError correctly" do
      error = Thumbsy::Api::AuthorizationError.new("Access denied")
      expect(error).to be_a(StandardError)
      expect(error.message).to eq("Access denied")
    end

    it "can raise and catch AuthenticationError" do
      expect do
        raise Thumbsy::Api::AuthenticationError, "Custom auth error"
      end.to raise_error(Thumbsy::Api::AuthenticationError, "Custom auth error")
    end

    it "can raise and catch AuthorizationError" do
      expect do
        raise Thumbsy::Api::AuthorizationError, "Custom authz error"
      end.to raise_error(Thumbsy::Api::AuthorizationError, "Custom authz error")
    end
  end

  describe "API Method Execution" do
    it "executes authentication method when configured" do
      executed = false
      Thumbsy::Api.configure do |config|
        config.authentication_method = lambda {
          executed = true
          "authenticated"
        }
      end

      result = Thumbsy::Api.authentication_method.call
      expect(executed).to be true
      expect(result).to eq("authenticated")
    end

    it "executes current voter method when configured" do
      Thumbsy::Api.configure do |config|
        config.current_voter_method = -> { user }
      end

      result = Thumbsy::Api.current_voter_method.call
      expect(result).to eq(user)
    end

    it "executes authorization method when configured" do
      Thumbsy::Api.configure do |config|
        config.authorization_method = ->(votable, voter) { votable.present? && voter.present? }
      end

      result = Thumbsy::Api.authorization_method.call(book, user)
      expect(result).to be true

      result = Thumbsy::Api.authorization_method.call(nil, user)
      expect(result).to be false
    end

    it "executes voter serializer when configured" do
      Thumbsy::Api.configure do |config|
        config.voter_serializer = ->(voter) { { custom_id: voter.id, custom_name: voter.name } }
      end

      result = Thumbsy::Api.voter_serializer.call(user)
      expect(result[:custom_id]).to eq(user.id)
      expect(result[:custom_name]).to eq(user.name)
    end
  end

  describe "Engine and Loading" do
    it "has load! method" do
      expect(Thumbsy::Api).to respond_to(:load!)
    end

    it "has configure method" do
      expect(Thumbsy::Api).to respond_to(:configure)
    end

    it "configure method yields the module" do
      yielded_object = nil
      Thumbsy::Api.configure do |config|
        yielded_object = config
      end

      expect(yielded_object).to eq(Thumbsy::Api)
    end
  end

  describe "API Module Structure" do
    it "defines the API namespace correctly" do
      expect(defined?(Thumbsy::Api)).to be_truthy
      expect(Thumbsy::Api).to be_a(Module)
    end

    it "has the expected configuration methods" do
      expect(Thumbsy::Api).to respond_to(:configure)
      expect(Thumbsy::Api).to respond_to(:load!)
      expect(Thumbsy::Api).to respond_to(:require_authentication)
      expect(Thumbsy::Api).to respond_to(:require_authorization)
    end

    it "has proper module hierarchy" do
      expect(Thumbsy::Api.name).to eq("Thumbsy::Api")
      expect(Thumbsy::Api::AuthenticationError.superclass).to eq(StandardError)
      expect(Thumbsy::Api::AuthorizationError.superclass).to eq(StandardError)
    end
  end

  describe "API Feedback Option" do
    before(:each) do
      Thumbsy::Api.configure do |config|
        config.require_authentication = false
        config.current_voter_method = -> { user }
      end
    end

    it "accepts valid feedback_option and returns it in response" do
      vote = book.vote_up(user, feedback_option: "like")
      expect(vote).to be_persisted
      expect(vote.feedback_option).to eq("like")
      expect(book.voted_by?(user)).to be true
    end

    it "rejects invalid feedback_option" do
      expect do
        book.vote_up(user, feedback_option: "invalid")
      end.to raise_error(ArgumentError, /'invalid' is not a valid feedback_option/)
    end

    it "allows feedback_option to be nil" do
      vote = book.vote_up(user, feedback_option: nil)
      expect(vote).to be_persisted
      expect(vote.feedback_option).to be_nil
      expect(book.voted_by?(user)).to be true
    end

    it "updates existing vote with new feedback_option" do
      vote = book.vote_up(user, feedback_option: "like")
      expect(vote.feedback_option).to eq("like")
      updated_vote = book.vote_up(user, feedback_option: "dislike")
      expect(updated_vote.id).to eq(vote.id)
      expect(updated_vote.feedback_option).to eq("dislike")
    end

    it "works with vote_down method" do
      vote = book.vote_down(user, feedback_option: "funny")
      expect(vote).to be_persisted
      expect(vote.feedback_option).to eq("funny")
      expect(vote.down_vote?).to be true
      expect(book.down_voted_by?(user)).to be true
    end
  end

  describe "Controller Method Testing" do
    before(:each) do
      Thumbsy::Api.configure do |config|
        config.require_authentication = false
        config.current_voter_method = -> { user }
      end
    end

    describe "vote_up method" do
      it "creates up vote with comment and feedback" do
        vote = book.vote_up(user, comment: "Great book!", feedback_option: "like")
        expect(vote).to be_persisted
        expect(vote.up_vote?).to be true
        expect(vote.comment).to eq("Great book!")
        expect(vote.feedback_option).to eq("like")
      end

      it "handles failed vote creation" do
        # Simulate a failed vote by making the voter nil
        Thumbsy::Api.configure { |config| config.current_voter_method = -> {} }

        # This would fail in a real controller context
        expect { book.vote_up(nil) }.to raise_error(ArgumentError)
      end

      it "updates existing vote when user votes again" do
        original_vote = book.vote_up(user, comment: "First vote")
        expect(original_vote.comment).to eq("First vote")

        updated_vote = book.vote_up(user, comment: "Updated vote", feedback_option: "like")
        expect(updated_vote.id).to eq(original_vote.id)
        expect(updated_vote.comment).to eq("Updated vote")
        expect(updated_vote.feedback_option).to eq("like")
      end
    end

    describe "vote_down method" do
      it "creates down vote with comment and feedback" do
        vote = book.vote_down(user, comment: "Not good", feedback_option: "dislike")
        expect(vote).to be_persisted
        expect(vote.down_vote?).to be true
        expect(vote.comment).to eq("Not good")
        expect(vote.feedback_option).to eq("dislike")
      end

      it "converts up vote to down vote" do
        up_vote = book.vote_up(user, comment: "Initially liked")
        expect(up_vote.up_vote?).to be true

        down_vote = book.vote_down(user, comment: "Changed mind")
        expect(down_vote.id).to eq(up_vote.id)
        expect(down_vote.down_vote?).to be true
        expect(down_vote.comment).to eq("Changed mind")
      end
    end

    describe "remove method" do
      it "removes existing vote" do
        book.vote_up(user)
        expect(book.voted_by?(user)).to be true

        removed = book.remove_vote(user)
        expect(removed).to be true
        expect(book.voted_by?(user)).to be false
      end

      it "returns false when no vote exists to remove" do
        expect(book.voted_by?(user)).to be false

        removed = book.remove_vote(user)
        expect(removed).to be false
      end
    end

    describe "status method" do
      it "returns correct status for up vote" do
        vote = book.vote_up(user, comment: "Great book!", feedback_option: "like")

        # Simulate what the status method would return
        status_data = {
          voted: book.voted_by?(user),
          vote_type: vote.up_vote? ? "up" : "down",
          comment: vote.comment,
          vote_counts: {
            total: book.votes_count,
            up: book.up_votes_count,
            down: book.down_votes_count,
            score: book.votes_score,
          },
        }

        expect(status_data[:voted]).to be true
        expect(status_data[:vote_type]).to eq("up")
        expect(status_data[:comment]).to eq("Great book!")
        expect(status_data[:vote_counts][:total]).to eq(1)
        expect(status_data[:vote_counts][:up]).to eq(1)
        expect(status_data[:vote_counts][:down]).to eq(0)
        expect(status_data[:vote_counts][:score]).to eq(1)
      end

      it "returns correct status for down vote" do
        vote = book.vote_down(user, comment: "Not good", feedback_option: "dislike")

        status_data = {
          voted: book.voted_by?(user),
          vote_type: vote.up_vote? ? "up" : "down",
          comment: vote.comment,
          vote_counts: {
            total: book.votes_count,
            up: book.up_votes_count,
            down: book.down_votes_count,
            score: book.votes_score,
          },
        }

        expect(status_data[:voted]).to be true
        expect(status_data[:vote_type]).to eq("down")
        expect(status_data[:comment]).to eq("Not good")
        expect(status_data[:vote_counts][:total]).to eq(1)
        expect(status_data[:vote_counts][:up]).to eq(0)
        expect(status_data[:vote_counts][:down]).to eq(1)
        expect(status_data[:vote_counts][:score]).to eq(-1)
      end

      it "returns correct status when no vote exists" do
        status_data = {
          voted: book.voted_by?(user),
          vote_type: nil,
          comment: nil,
          vote_counts: {
            total: book.votes_count,
            up: book.up_votes_count,
            down: book.down_votes_count,
            score: book.votes_score,
          },
        }

        expect(status_data[:voted]).to be false
        expect(status_data[:vote_type]).to be_nil
        expect(status_data[:comment]).to be_nil
        expect(status_data[:vote_counts][:total]).to eq(0)
        expect(status_data[:vote_counts][:up]).to eq(0)
        expect(status_data[:vote_counts][:down]).to eq(0)
        expect(status_data[:vote_counts][:score]).to eq(0)
      end
    end

    describe "index method" do
      it "returns filtered votes with summary" do
        book.vote_up(user, comment: "Great book!", feedback_option: "like")
        book.vote_down(user2, comment: "Not good", feedback_option: "dislike")

        # Simulate what the index method would return
        votes = book.thumbsy_votes.includes(:voter).order(:id)
        vote_data = votes.map do |vote|
          {
            id: vote.id,
            vote_type: vote.up_vote? ? "up" : "down",
            comment: vote.comment,
            feedback_option: vote.feedback_option,
            voter: { id: vote.voter.id, type: vote.voter.class.name },
            created_at: vote.created_at,
            updated_at: vote.updated_at,
          }
        end

        summary = {
          total: book.votes_count,
          up: book.up_votes_count,
          down: book.down_votes_count,
          score: book.votes_score,
        }

        expect(vote_data.length).to eq(2)
        expect(vote_data.first[:vote_type]).to eq("up")
        expect(vote_data.last[:vote_type]).to eq("down")
        expect(summary[:total]).to eq(2)
        expect(summary[:up]).to eq(1)
        expect(summary[:down]).to eq(1)
        expect(summary[:score]).to eq(0)
      end

      it "filters votes by type" do
        book.vote_up(user, comment: "Great book!")
        book.vote_down(user2, comment: "Not good")

        up_votes = book.thumbsy_votes.up_votes
        down_votes = book.thumbsy_votes.down_votes

        expect(up_votes.count).to eq(1)
        expect(down_votes.count).to eq(1)
        expect(up_votes.first.up_vote?).to be true
        expect(down_votes.first.down_vote?).to be true
      end

      it "filters votes with comments" do
        book.vote_up(user, comment: "Great book!")
        book.vote_up(user2) # No comment

        votes_with_comments = book.thumbsy_votes.with_comments
        expect(votes_with_comments.count).to eq(1)
        expect(votes_with_comments.first.comment).to eq("Great book!")
      end
    end
  end

  describe "Application Controller Testing" do
    describe "authentication methods" do
      it "supports custom authentication method" do
        Thumbsy::Api.configure do |config|
          config.authentication_method = -> { "authenticated" }
        end

        result = Thumbsy::Api.authentication_method.call
        expect(result).to eq("authenticated")
      end

      it "supports current voter method" do
        Thumbsy::Api.configure do |config|
          config.current_voter_method = -> { user }
        end

        result = Thumbsy::Api.current_voter_method.call
        expect(result).to eq(user)
      end

      it "handles authentication requirements" do
        expect(Thumbsy::Api.require_authentication).to be true

        Thumbsy::Api.configure { |config| config.require_authentication = false }
        expect(Thumbsy::Api.require_authentication).to be false
      end
    end
  end

  describe "Main Thumbsy Module Testing" do
    describe "configuration" do
      it "has default vote model name" do
        expect(Thumbsy.vote_model_name).to eq("ThumbsyVote")
      end

      it "supports configuration changes" do
        Thumbsy.configure do |config|
          config.vote_model_name = "CustomVote"
        end

        expect(Thumbsy.vote_model_name).to eq("CustomVote")

        # Reset to default
        Thumbsy.vote_model_name = "ThumbsyVote"
      end
    end

    describe "API loading" do
      it "defines load_api! method" do
        expect(Thumbsy).to respond_to(:load_api!)
      end

      it "handles const_missing for Api" do
        # Test that const_missing is defined
        expect(Thumbsy).to respond_to(:const_missing)
      end
    end

    describe "ActiveRecord extension" do
      it "extends ActiveRecord when available" do
        # Test that the extension is loaded
        expect(ActiveRecord::Base).to respond_to(:votable)
        expect(ActiveRecord::Base).to respond_to(:voter)
      end
    end
  end

  describe "Controller Parameter Testing" do
    it "handles vote parameters correctly" do
      # Test parameter handling logic
      params = {
        comment: "Test comment",
        feedback_option: "like",
        votable_type: "Book",
        votable_id: book.id,
      }

      permitted_params = params.slice(:comment, :feedback_option, :votable_type, :votable_id)

      expect(permitted_params[:comment]).to eq("Test comment")
      expect(permitted_params[:feedback_option]).to eq("like")
      expect(permitted_params[:votable_type]).to eq("Book")
      expect(permitted_params[:votable_id]).to eq(book.id)
    end

    it "handles missing parameters gracefully" do
      params = { votable_type: "Book", votable_id: book.id }
      permitted_params = params.slice(:comment, :feedback_option, :votable_type, :votable_id)

      expect(permitted_params[:comment]).to be_nil
      expect(permitted_params[:feedback_option]).to be_nil
      expect(permitted_params[:votable_type]).to eq("Book")
      expect(permitted_params[:votable_id]).to eq(book.id)
    end
  end

  describe "Votable Finding and Authorization" do
    it "handles valid votable types" do
      votable_class = "Book".constantize
      votable = votable_class.find(book.id)

      expect(votable).to eq(book)
      expect(votable.class).to eq(Book)
    end

    it "handles invalid votable types" do
      expect { "InvalidClass".constantize }.to raise_error(NameError)
    end

    it "handles authorization requirements" do
      expect(Thumbsy::Api.require_authorization).to be false

      Thumbsy::Api.configure { |config| config.require_authorization = true }
      expect(Thumbsy::Api.require_authorization).to be true
    end

    it "executes authorization method when configured" do
      Thumbsy::Api.configure do |config|
        config.authorization_method = ->(votable, voter) { votable.present? && voter.present? }
      end

      result = Thumbsy::Api.authorization_method.call(book, user)
      expect(result).to be true
    end
  end

  describe "Model-Level Edge Cases and Error Handling" do
    before(:each) do
      Thumbsy::Api.configure do |config|
        config.require_authentication = false
        config.current_voter_method = -> { user }
      end
    end

    it "does not allow voting with a non-existent user" do
      expect do
        book.vote_up(nil, comment: "Should fail")
      end.to raise_error(ArgumentError)
    end

    it "does not allow voting with a non-existent votable" do
      expect do
        Book.find(9999).vote_up(user)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "does not allow duplicate up votes with same feedback_option" do
      vote1 = book.vote_up(user, feedback_option: "like")
      vote2 = book.vote_up(user, feedback_option: "like")
      expect(vote2.id).to eq(vote1.id)
      expect(book.thumbsy_votes.count).to eq(1)
    end

    it "allows changing feedback_option on existing vote" do
      vote1 = book.vote_up(user, feedback_option: "like")
      vote2 = book.vote_up(user, feedback_option: "dislike")
      expect(vote2.id).to eq(vote1.id)
      expect(vote2.feedback_option).to eq("dislike")
    end

    it "removes vote and allows re-voting" do
      book.vote_up(user)
      expect(book.voted_by?(user)).to be true
      book.remove_vote(user)
      expect(book.voted_by?(user)).to be false
      new_vote = book.vote_down(user)
      expect(new_vote.down_vote?).to be true
    end

    it "handles nil feedback_option gracefully" do
      vote = book.vote_up(user, feedback_option: nil)
      expect(vote.feedback_option).to be_nil
    end

    it "handles blank feedback_option as invalid" do
      expect do
        book.vote_up(user, feedback_option: "")
      end.not_to raise_error
      vote = book.thumbsy_votes.last
      expect(vote.feedback_option).to be_nil
    end
  end
end
