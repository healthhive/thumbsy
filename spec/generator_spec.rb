# frozen_string_literal: true

require "spec_helper"
require "rails/generators"
require_relative "../lib/generators/thumbsy/install_generator"
require_relative "../lib/generators/thumbsy/api_generator"

RSpec.describe "Thumbsy Generators" do
  describe "InstallGenerator" do
    let(:generator) { Thumbsy::Generators::InstallGenerator.new([], { feedback: %w[like dislike funny] }) }

    it "has correct source root" do
      expect(generator.class.source_root).to include("templates")
    end

    it "has correct description" do
      expect(generator.class.desc).to include("Installs Thumbsy")
    end

    it "has feedback option with default values" do
      expect(generator.options[:feedback]).to eq(%w[like dislike funny])
    end

    it "defines next_migration_number method" do
      expect(generator.class).to respond_to(:next_migration_number)
    end

    it "has create_migration_file method" do
      expect(generator).to respond_to(:create_migration_file)
    end

    it "has create_thumbsy_vote_model method" do
      expect(generator).to respond_to(:create_thumbsy_vote_model)
    end

    it "has show_readme method" do
      expect(generator).to respond_to(:show_readme)
    end
  end

  describe "ApiGenerator" do
    let(:generator) { Thumbsy::Generators::ApiGenerator.new([], [], {}) }

    it "has correct source root" do
      expect(generator.class.source_root).to include("templates")
    end

    it "has correct description" do
      expect(generator.class.desc).to include("Generate Thumbsy API")
    end

    it "has create_api_initializer method" do
      expect(generator).to respond_to(:create_api_initializer)
    end

    it "has add_api_require method" do
      expect(generator).to respond_to(:add_api_require)
    end

    it "has add_routes method" do
      expect(generator).to respond_to(:add_routes)
    end

    it "has show_instructions method" do
      expect(generator).to respond_to(:show_instructions)
    end
  end

  describe "Generator Integration" do
    it "can instantiate install generator" do
      generator = Thumbsy::Generators::InstallGenerator.new([], [], {})
      expect(generator).to be_a(Thumbsy::Generators::InstallGenerator)
    end

    it "can instantiate API generator" do
      generator = Thumbsy::Generators::ApiGenerator.new([], [], {})
      expect(generator).to be_a(Thumbsy::Generators::ApiGenerator)
    end

    it "generators inherit from Rails::Generators::Base" do
      expect(Thumbsy::Generators::InstallGenerator).to be < Rails::Generators::Base
      expect(Thumbsy::Generators::ApiGenerator).to be < Rails::Generators::Base
    end

    it "install generator includes migration generator" do
      expect(Thumbsy::Generators::InstallGenerator.ancestors).to include(Rails::Generators::Migration)
    end
  end
end
