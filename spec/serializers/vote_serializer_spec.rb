# frozen_string_literal: true

require "spec_helper"

require "thumbsy/api"
require "thumbsy/api/serializers/vote_serializer"

# Test models for serializer spec
class SerializerTestUser < ActiveRecord::Base
  self.table_name = "users"
  voter
end

class SerializerTestBook < ActiveRecord::Base
  self.table_name = "books"
  votable
end

RSpec.describe Thumbsy::Api::Serializers::VoteSerializer do
  before(:all) do
    Thumbsy.feedback_options = %w[like dislike funny]
    Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
    load "lib/thumbsy/models/thumbsy_vote.rb"
  end

  before(:each) do
    Thumbsy::Api.configure do |config|
      config.require_authentication = false
      config.require_authorization = false
      config.authentication_method = nil
      config.current_voter_method = -> { SerializerTestUser.first }
      config.authorization_method = nil
      config.voter_serializer = nil
    end
  end

  let!(:user) { SerializerTestUser.create!(name: "Serializer User") }
  let!(:book) { SerializerTestBook.create!(title: "Serializer Book") }
  let(:vote) { book.vote_up(user, comment: "Test vote", feedback_option: "like") }
  let(:serializer) { described_class.new(vote) }

  describe "#as_json" do
    it "returns vote data without timestamps" do
      result = serializer.as_json

      expect(result).to include(
        id: vote.id,
        vote_type: "up",
        comment: "Test vote",
        feedback_option: "like",
      )

      # Verify timestamps are NOT included
      expect(result).not_to have_key(:created_at)
      expect(result).not_to have_key(:updated_at)
    end

    it "includes voter data with default serializer" do
      result = serializer.as_json

      expect(result[:voter]).to include(
        id: user.id,
        type: "SerializerTestUser",
      )
    end

    it "uses custom voter serializer when configured" do
      Thumbsy::Api.configure do |config|
        config.voter_serializer = ->(voter) { { custom_id: voter.id, custom_name: voter.name } }
      end

      result = serializer.as_json

      expect(result[:voter]).to include(
        custom_id: user.id,
        custom_name: user.name,
      )
    end

    it "handles down votes correctly" do
      down_vote = book.vote_down(user, comment: "Down vote", feedback_option: "dislike")
      serializer = described_class.new(down_vote)
      result = serializer.as_json

      expect(result).to include(
        vote_type: "down",
        comment: "Down vote",
        feedback_option: "dislike",
      )
    end

    it "handles votes without comment and feedback_option" do
      vote_without_optional = book.vote_up(user)
      serializer = described_class.new(vote_without_optional)

      result = serializer.as_json

      expect(result).to include(
        vote_type: "up",
        comment: nil,
        feedback_option: nil,
      )
    end
  end
end
