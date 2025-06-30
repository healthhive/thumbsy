# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Thumbsy API Components", :api do
  describe "API module loading" do
    it "can load the API module without errors" do
      expect { require "thumbsy/api" }.not_to raise_error
    end

    it "defines the API namespace" do
      require "thumbsy/api"
      expect(defined?(Thumbsy::Api)).to be_truthy
    end

    it "loads API configuration" do
      require "thumbsy/api"
      expect(Thumbsy::Api).to respond_to(:configure)
    end

    it "supports autoloading of API module" do
      # Test that accessing Thumbsy::Api works without explicit require
      # This tests the const_missing hook
      expect(Thumbsy::Api).to be_a(Module)
      expect(Thumbsy::Api).to respond_to(:configure)
      expect(Thumbsy::Api).to respond_to(:load!)

      # Verify the module has expected configuration
      expect(Thumbsy::Api.require_authentication).to be_in([true, false])
      expect(Thumbsy::Api.require_authorization).to be_in([true, false])
    end
  end

  describe "API integration readiness" do
    before do
      require "thumbsy/api"
    rescue StandardError
      nil
    end

    it "has API components available when loaded" do
      expect(defined?(Thumbsy::Api)).to be_truthy
    end

    it "can be configured when API is available" do
      expect do
        Thumbsy::Api.configure do |config|
          config.require_authentication = false
        end
      end.not_to raise_error
    end
  end

  describe "Core functionality works without API" do
    let(:user) { User.create!(name: "Test User") }
    let(:book) { Book.create!(title: "Test Book") }

    before do
      # Define test models
      class User < ActiveRecord::Base
        voter
      end

      class Book < ActiveRecord::Base
        votable
      end
    end

    it "voting works without API loaded" do
      result = book.vote_up(user)
      expect(result).to be_persisted
      expect(book.voted_by?(user)).to be true
    end

    it "voting from voter perspective works" do
      result = user.vote_up_for(book)
      expect(result).to be_persisted
      expect(user.voted_for?(book)).to be true
    end
  end
end
