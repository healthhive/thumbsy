#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to automatically bump version and create git tag based on conventional commits
# Usage: ruby script/bump_version.rb [patch|minor|major]
# If no argument provided, automatically determines bump type from commit messages

require "open3"
require "json"

class VersionBumper
  VERSION_FILE = "lib/thumbsy/version.rb"
  GEMSPEC_FILE = "thumbsy.gemspec"

  def initialize
    @current_version = read_current_version
    @bump_type = determine_bump_type
  end

  def run
    puts "🎯 Current version: #{@current_version}"
    puts "📈 Bump type: #{@bump_type}"

    new_version = calculate_new_version
    puts "🚀 New version: #{new_version}"

    if confirm_bump?(new_version)
      update_version_files(new_version)
      commit_and_tag(new_version)
      puts "✅ Version bumped to #{new_version} and tagged!"
    else
      puts "❌ Version bump cancelled"
      exit 1
    end
  end

  private

  def read_current_version
    version_content = File.read(VERSION_FILE)
    version_content.match(/VERSION = "([^"]+)"/)[1]
  end

  def determine_bump_type
    return ARGV[0] if ARGV[0] && %w[patch minor major].include?(ARGV[0])

    # Get commits since last tag
    last_tag = get_last_tag
    commits = get_commits_since_tag(last_tag)

    puts "📝 Analyzing #{commits.length} commits since last tag..."

    bump_type = "patch" # Default to patch

    commits.each do |commit|
      message = commit[:message].downcase

      # Major: breaking changes
      if message.include?("breaking change") || message.include?("!") || message.match(/^.*!:.*/)
        bump_type = "major"
        break
      end

      # Minor: new features
      bump_type = "minor" if (message.start_with?("feat:") || message.start_with?("feature:")) && (bump_type == "patch")
    end

    bump_type
  end

  def get_last_tag
    stdout, = Open3.capture3('git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0"')
    stdout.strip
  end

  def get_commits_since_tag(last_tag)
    stdout, = Open3.capture3("git log #{last_tag}..HEAD --oneline --format='%H|%s|%b'")

    stdout.lines.map do |line|
      hash, subject, body = line.strip.split("|", 3)
      {
        hash: hash,
        message: subject,
        body: body || "",
      }
    end
  end

  def calculate_new_version
    major, minor, patch = @current_version.split(".").map(&:to_i)

    case @bump_type
    when "major"
      "#{major + 1}.0.0"
    when "minor"
      "#{major}.#{minor + 1}.0"
    when "patch"
      "#{major}.#{minor}.#{patch + 1}"
    else
      raise "Invalid bump type: #{@bump_type}"
    end
  end

  def confirm_bump?(new_version)
    puts "\n🤔 Confirm version bump?"
    puts "   From: #{@current_version}"
    puts "   To:   #{new_version}"
    puts "   Type: #{@bump_type}"
    print "\nContinue? (y/N): "

    response = STDIN.gets.chomp.downcase
    %w[y yes].include?(response)
  end

  def update_version_files(new_version)
    puts "🔄 Updating version files..."

    # Update lib/thumbsy/version.rb
    content = File.read(VERSION_FILE)
    content.gsub!(/VERSION = "[^"]+"/, "VERSION = \"#{new_version}\"")
    File.write(VERSION_FILE, content)

    # Update thumbsy.gemspec
    content = File.read(GEMSPEC_FILE)
    content.gsub!(/spec\.version\s+= "[^"]+"/, "spec.version       = \"#{new_version}\"")
    File.write(GEMSPEC_FILE, content)

    puts "✅ Version files updated"
  end

  def commit_and_tag(new_version)
    puts "📝 Committing version bump..."

    # Add version files
    system("git add", VERSION_FILE, GEMSPEC_FILE)

    # Commit
    commit_message = "chore: bump version to #{new_version}"
    system("git", "commit", "-m", commit_message)

    # Create and push tag
    tag_name = "v#{new_version}"
    system("git", "tag", "-a", tag_name, "-m", "Release #{new_version}")

    puts "🏷️  Tag #{tag_name} created"
    puts "📤 Push the tag to trigger release: git push origin #{tag_name}"
  end
end

if __FILE__ == $0
  begin
    VersionBumper.new.run
  rescue StandardError => e
    puts "❌ Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    exit 1
  end
end
