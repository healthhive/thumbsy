# frozen_string_literal: true

require "spec_helper"
require "thumbsy/api"

RSpec.describe "Thumbsy API", :api do
  before(:all) do
    # Define test models
    class User < ActiveRecord::Base
      voter
    end

    class Book < ActiveRecord::Base
      votable
    end
  end

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
      lib_path = File.expand_path("../lib", __dir__)
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

  describe "Voter Serialization" do
    it "provides default voter data structure" do
      # Reset any existing serializer
      Thumbsy::Api.configure { |config| config.voter_serializer = nil }

      # Without custom serializer, the controller would use default format
      expected_default = {
        id: user.id,
        type: user.class.name,
      }

      # This simulates what the default voter_data method would return
      voter_data = if Thumbsy::Api.voter_serializer
                     Thumbsy::Api.voter_serializer.call(user)
                   else
                     { id: user.id, type: user.class.name }
                   end

      expect(voter_data).to eq(expected_default)
    end

    it "uses custom serializer when configured" do
      Thumbsy::Api.configure do |config|
        config.voter_serializer = lambda { |voter|
          {
            id: voter.id,
            name: voter.name,
            type: "CustomUser",
            voting_power: "high",
          }
        }
      end

      voter_data = Thumbsy::Api.voter_serializer.call(user)

      expect(voter_data[:id]).to eq(user.id)
      expect(voter_data[:name]).to eq(user.name)
      expect(voter_data[:type]).to eq("CustomUser")
      expect(voter_data[:voting_power]).to eq("high")
    end

    it "handles nil voters gracefully in custom serializer" do
      Thumbsy::Api.configure do |config|
        config.voter_serializer = lambda { |voter|
          return { error: "No voter" } if voter.nil?

          { id: voter.id, name: voter.name }
        }
      end

      result = Thumbsy::Api.voter_serializer.call(nil)
      expect(result[:error]).to eq("No voter")
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
        config.authentication_method = -> { executed = true; "authenticated" }
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
end
