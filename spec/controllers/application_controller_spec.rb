# frozen_string_literal: true

require "spec_helper"
require "action_controller"
require "action_controller/api"
require "thumbsy/api" # <-- Ensure Thumbsy::Api is loaded
require "thumbsy/api/controllers/application_controller"

# Define a concrete test controller for direct testing
class TestAppController < Thumbsy::Api::ApplicationController
  public :authenticate_voter!, :set_current_voter, :authentication_required?, :render_success, :render_error,
         :render_not_found

  attr_writer :_request, :_response

  def request
    @_request ||= ActionController::TestRequest.create(self.class) # rubocop:disable Naming/MemoizedInstanceVariableName
  end

  def response
    @_response ||= ActionDispatch::TestResponse.new # rubocop:disable Naming/MemoizedInstanceVariableName
  end

  def test_render_success
    render_success({ foo: "bar" }, :created)
  end

  def test_render_error
    render_error("Something went wrong", :unprocessable_entity, { details: "error details" })
  end

  def test_render_not_found
    render_not_found(nil)
  end
end

RSpec.describe TestAppController do
  let(:controller) { TestAppController.new }
  let(:user) { double("User", present?: true) }

  before do
    controller._request = ActionController::TestRequest.create(TestAppController)
    controller._response = ActionDispatch::TestResponse.new
  end

  describe "#authenticate_voter!" do
    it "calls authentication_method if set" do
      called = false
      Thumbsy::Api.configure do |config|
        config.authentication_method = ->(*_args) { called = true }
      end
      expect { controller.authenticate_voter! }.not_to raise_error
      expect(called).to be true
    end

    it "returns unauthorized if no current_voter and no authentication_method" do
      Thumbsy::Api.configure do |config|
        config.authentication_method = nil
      end
      allow(controller).to receive(:current_voter).and_return(nil)
      expect(controller).to receive(:head).with(:unauthorized)
      controller.authenticate_voter!
    end

    it "does nothing if current_voter is present and no authentication_method" do
      Thumbsy::Api.configure do |config|
        config.authentication_method = nil
      end
      allow(controller).to receive(:current_voter).and_return(user)
      expect(controller).not_to receive(:head)
      controller.authenticate_voter!
    end
  end

  describe "#set_current_voter" do
    it "sets @current_voter using current_voter_method if set" do
      Thumbsy::Api.configure do |config|
        config.current_voter_method = ->(*_args) { :the_voter }
      end
      controller.set_current_voter
      expect(controller.instance_variable_get(:@current_voter)).to eq(:the_voter)
    end

    it "sets @current_voter using current_user if no current_voter_method" do
      Thumbsy::Api.configure do |config|
        config.current_voter_method = nil
      end
      allow(controller).to receive(:current_user).and_return(:user_from_method)
      controller.set_current_voter
      expect(controller.instance_variable_get(:@current_voter)).to eq(:user_from_method)
    end
  end

  describe "#authentication_required?" do
    it "returns true if require_authentication is true" do
      Thumbsy::Api.configure { |c| c.require_authentication = true }
      expect(controller.authentication_required?).to be true
    end
    it "returns false if require_authentication is false" do
      Thumbsy::Api.configure { |c| c.require_authentication = false }
      expect(controller.authentication_required?).to be false
    end
  end

  describe "render helpers" do
    it "render_success returns correct JSON and status" do
      controller.test_render_success
      expect(controller.response.status).to eq(201)
      expect(JSON.parse(controller.response.body)).to eq({ "success" => true, "data" => { "foo" => "bar" } })
    end
    it "render_error returns correct JSON and status" do
      controller.test_render_error
      expect(controller.response.status).to eq(422)
      expect(JSON.parse(controller.response.body)).to eq({ "success" => false, "error" => "Something went wrong",
                                                           "errors" => { "details" => "error details" } })
    end
    it "render_not_found returns correct JSON and status" do
      controller.test_render_not_found
      expect(controller.response.status).to eq(404)
      expect(JSON.parse(controller.response.body)).to eq({ "success" => false, "error" => "Resource not found",
                                                           "errors" => {} })
    end
  end
end
