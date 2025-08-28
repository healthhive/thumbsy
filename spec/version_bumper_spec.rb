# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Version Bumper Script" do
  let(:version_file) { "lib/thumbsy/version.rb" }
  let(:gemspec_file) { "thumbsy.gemspec" }
  let(:script_path) { "script/bump_version.rb" }

  before do
    # Backup original files
    @original_version_content = File.read(version_file)
    @original_gemspec_content = File.read(gemspec_file)
  end

  after do
    # Restore original files
    File.write(version_file, @original_version_content)
    File.write(gemspec_file, @original_gemspec_content)
  end

  describe "script execution" do
    it "can be loaded without errors" do
      expect { load script_path }.not_to raise_error
    end

    it "defines the VersionBumper class" do
      load script_path
      expect(defined?(VersionBumper)).to be_truthy
    end
  end

  describe "VersionBumper class" do
    before { load script_path }

    let(:bumper) { VersionBumper.new }

    describe "#read_current_version" do
      it "reads the current version from version.rb" do
        expect(bumper.send(:read_current_version)).to eq("1.0.0")
      end
    end

    describe "#calculate_new_version" do
      it "calculates patch version correctly" do
        bumper.instance_variable_set(:@bump_type, "patch")
        expect(bumper.send(:calculate_new_version)).to eq("1.0.1")
      end

      it "calculates minor version correctly" do
        bumper.instance_variable_set(:@bump_type, "minor")
        expect(bumper.send(:calculate_new_version)).to eq("1.1.0")
      end

      it "calculates major version correctly" do
        bumper.instance_variable_set(:@bump_type, "major")
        expect(bumper.send(:calculate_new_version)).to eq("2.0.0")
      end
    end

    describe "version file constants" do
      it "defines correct file paths" do
        expect(VersionBumper::VERSION_FILE).to eq("lib/thumbsy/version.rb")
        expect(VersionBumper::GEMSPEC_FILE).to eq("thumbsy.gemspec")
      end
    end
  end

  describe "script file permissions" do
    it "is executable" do
      expect(File.executable?(script_path)).to be true
    end
  end
end
