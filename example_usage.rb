#!/usr/bin/env ruby
# frozen_string_literal: true

# Example demonstrating that Thumbsy::Api is now accessible without explicit require
# This file demonstrates the fix for "uninitialized constant Thumbsy::Api" error
#
# NOTE: This gem requires Rails/ActiveSupport to be available.
# Run this example within a Rails application context.

puts "🧪 Demonstrating Thumbsy::Api autoloading fix..."
puts "📋 Note: This example requires Rails/ActiveSupport environment"
puts

# Check if we're in a Rails context
if !defined?(Rails) && !defined?(ActiveSupport)
  puts "❌ This example requires a Rails environment."
  puts "💡 To test the fix:"
  puts "   1. Create a Rails app: rails new test_app"
  puts "   2. Add thumbsy to Gemfile: gem 'thumbsy', path: '/path/to/thumbsy'"
  puts "   3. Run: bundle install"
  puts "   4. Test in rails console: require 'thumbsy'; Thumbsy::Api.configure {...}"
  puts
  puts "🧪 Alternatively, run the RSpec test that verifies autoloading:"
  puts "   bundle exec rspec -e 'supports autoloading'"
  exit 0
end

# Step 1: Require the main thumbsy gem
puts "1. Requiring 'thumbsy' gem..."
require 'thumbsy'
puts "   ✅ Thumbsy gem loaded successfully"

# Step 2: Access Thumbsy::Api directly (this should work now!)
puts "2. Accessing Thumbsy::Api module..."
begin
  api_module = Thumbsy::Api
  puts "   ✅ Thumbsy::Api accessible: #{api_module}"
rescue NameError => e
  puts "   ❌ Error: #{e.message}"
  exit 1
end

# Step 3: Check API configuration methods
puts "3. Testing API configuration methods..."
begin
  puts "   - require_authentication: #{Thumbsy::Api.require_authentication}"
  puts "   - require_authorization: #{Thumbsy::Api.require_authorization}"
  puts "   ✅ Configuration methods work"
rescue => e
  puts "   ❌ Configuration error: #{e.message}"
  exit 1
end

# Step 4: Configure the API
puts "4. Configuring Thumbsy::Api..."
begin
  Thumbsy::Api.configure do |config|
    config.require_authentication = false
    config.require_authorization = true
  end

  puts "   - Updated require_authentication: #{Thumbsy::Api.require_authentication}"
  puts "   - Updated require_authorization: #{Thumbsy::Api.require_authorization}"
  puts "   ✅ API configuration successful"
rescue => e
  puts "   ❌ Configuration failed: #{e.message}"
  exit 1
end

# Step 5: Check exception classes
puts "5. Testing exception classes..."
begin
  auth_error = Thumbsy::Api::AuthenticationError.new("Test auth error")
  authz_error = Thumbsy::Api::AuthorizationError.new("Test authz error")

  puts "   - AuthenticationError: #{auth_error.class}"
  puts "   - AuthorizationError: #{authz_error.class}"
  puts "   ✅ Exception classes available"
rescue => e
  puts "   ❌ Exception classes error: #{e.message}"
  exit 1
end

# Step 6: Verify load! method exists (but don't call it - requires Rails)
puts "6. Checking load! method availability..."
begin
  if Thumbsy::Api.respond_to?(:load!)
    puts "   ✅ load! method available for full API functionality"
  else
    puts "   ❌ load! method not found"
    exit 1
  end
rescue => e
  puts "   ❌ Error checking load! method: #{e.message}"
  exit 1
end

puts
puts "🎉 SUCCESS! All tests passed!"
puts
puts "📋 What this demonstrates:"
puts "   • Thumbsy::Api is immediately accessible after requiring 'thumbsy'"
puts "   • Configuration methods work without explicit API require"
puts "   • Exception classes are available"
puts "   • load! method exists for full Rails integration"
puts
puts "✨ The 'uninitialized constant Thumbsy::Api' error is now fixed!"
puts
puts "💡 Usage in your Rails app:"
puts "   # In Gemfile:"
puts "   gem 'thumbsy'"
puts ""
puts "   # In an initializer or config/application.rb:"
puts "   Thumbsy::Api.configure { |c| c.require_authentication = false }"
puts "   Thumbsy.load_api!  # Load controllers and routes"
puts ""
puts "   # In your models:"
puts "   class User < ApplicationRecord"
puts "     voter"
puts "   end"
puts ""
puts "   class Post < ApplicationRecord"
puts "     votable"
puts "   end"
