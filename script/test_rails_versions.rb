#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to verify Thumbsy gem compatibility across Rails versions
# Usage: ruby script/test_rails_versions.rb

require "fileutils"
require "English"

class RailsVersionTester
  RAILS_VERSIONS = %w[7.1 7.2 8.0].freeze
  RUBY_VERSION_REQUIREMENT = "3.2.0"

  def initialize
    @results = {}
    @original_dir = Dir.pwd
    check_ruby_version
  end

  def run_all_tests
    puts "🚀 Testing Thumbsy gem compatibility across Rails versions"
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Testing Rails versions: #{RAILS_VERSIONS.join(", ")}"
    puts "=" * 60

    RAILS_VERSIONS.each do |version|
      test_rails_version(version)
      puts
    end

    print_summary
  end

  private

  def check_ruby_version
    current_version = Gem::Version.new(RUBY_VERSION)
    required_version = Gem::Version.new(RUBY_VERSION_REQUIREMENT)

    return unless current_version < required_version

    puts "❌ Ruby #{RUBY_VERSION_REQUIREMENT}+ required. Current: #{RUBY_VERSION}"
    exit 1
  end

  def test_rails_version(version)
    puts "🔧 Testing Rails #{version}..."

    start_time = Time.now

    # Set environment variable
    ENV["RAILS_VERSION"] = version

    # Update bundle
    bundle_result = run_command("bundle update rails", "Bundle update for Rails #{version}")
    return record_failure(version, "Bundle update failed") unless bundle_result

    # Run tests
    test_result = run_command("bundle exec rspec --format progress", "Test suite for Rails #{version}")

    duration = Time.now - start_time

    if test_result
      record_success(version, duration)
    else
      record_failure(version, "Test suite failed")
    end
  ensure
    # Clean up environment
    ENV.delete("RAILS_VERSION")
  end

  def run_command(command, description)
    puts "  Running: #{command}"

    # Capture both stdout and stderr
    output = `#{command} 2>&1`
    success = $CHILD_STATUS.success?

    if success
      puts "  ✅ #{description} - PASSED"
      # Show test summary for test runs
      if command.include?("rspec")
        summary_line = output.lines.find { |line| line.include?("examples") && line.include?("failures") }
        puts "  📊 #{summary_line.strip}" if summary_line
      end
    else
      puts "  ❌ #{description} - FAILED"
      puts "  Error output:"
      puts output.lines.last(5).map { |line| "    #{line}" }.join
    end

    success
  end

  def record_success(version, duration)
    @results[version] = {
      status: :success,
      duration: duration,
      message: "All tests passed",
    }
    puts "  🎉 Rails #{version} - SUCCESS (#{duration.round(2)}s)"
  end

  def record_failure(version, message)
    @results[version] = {
      status: :failure,
      message: message,
    }
    puts "  💥 Rails #{version} - FAILED: #{message}"
  end

  def print_summary
    puts "=" * 60
    puts "📋 SUMMARY"
    puts "=" * 60

    print_results
    print_final_status
  end

  def print_results
    @results.each do |version, result|
      status_icon = result[:status] == :success ? "✅" : "❌"
      duration_info = result[:duration] ? " (#{result[:duration].round(2)}s)" : ""
      puts "#{status_icon} Rails #{version}: #{result[:message]}#{duration_info}"
    end
  end

  def print_final_status
    successes = @results.values.count { |r| r[:status] == :success }
    failures = @results.values.count { |r| r[:status] == :failure }

    puts
    puts "🏆 Results: #{successes} passed, #{failures} failed"

    if failures.positive?
      puts "❌ Some tests failed. Check the output above for details."
      exit 1
    else
      puts "🎉 All Rails versions passed! Thumbsy is compatible across the board."
    end
  end
end

# Allow script to be run directly
if __FILE__ == $PROGRAM_NAME
  # Change to gem root directory
  script_dir = File.dirname(__FILE__)
  gem_root = File.expand_path("..", script_dir)
  Dir.chdir(gem_root)

  puts "📁 Working directory: #{Dir.pwd}"

  # Verify we're in the right place
  unless File.exist?("thumbsy.gemspec")
    puts "❌ Error: Not in Thumbsy gem directory (thumbsy.gemspec not found)"
    exit 1
  end

  tester = RailsVersionTester.new
  tester.run_all_tests
end
