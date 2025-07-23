# Thumbsy - Rails Voting Gem

[![CI](https://github.com/yourusername/thumbsy/workflows/CI/badge.svg)](https://github.com/yourusername/thumbsy/actions)

A Rails gem for adding thumbs up/down voting functionality with comments and feedback options.
Includes optional JSON API endpoints.

**Note**: This library was created with Claude Sonnet 4, based on the requirements specified in ORIGINAL_PROMPT.txt

## Requirements

- **Ruby**: 3.3.0 or newer
- **Rails**: 7.1, 7.2, or 8.0+
- **Database**: SQLite, PostgreSQL, or MySQL (any ActiveRecord-supported database)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'thumbsy'
```

And then execute:

```sh
bundle install
```

Run the install generator:

```sh
# Uses default feedback options (like, dislike, funny)
rails generate thumbsy:install

# Or specify custom feedback options
rails generate thumbsy:install --feedback=helpful,unhelpful,spam
```

**Note:**
- The `--feedback` option is **optional**. If omitted, the default feedback options are `like`, `dislike`, and `funny`.
- If you pass `--feedback` but do not provide any values (e.g., `--feedback` or `--feedback ""`), the generator will fail with an error.

## Basic Setup (ActiveRecord only)

```bash
# Generate migration and basic functionality
rails generate thumbsy:install
rails db:migrate
```

### ID Type Configuration

Thumbsy supports different primary key types to match your application's needs:

```bash
# Default ID type is UUID (recommended for distributed systems)
rails generate thumbsy:install

# Use big integers (recommended for high-volume applications)
rails generate thumbsy:install --id_type=bigint
```

The ID type affects:
- Primary key of the `thumbsy_votes` table
- Foreign key references to votable and voter models

### Custom Feedback Options

You can customize the feedback options when generating the model:

```bash
# Use default feedback options (like, dislike, funny)
rails generate thumbsy:install

# Use custom feedback options
rails generate thumbsy:install --feedback=helpful,unhelpful,spam
```

```ruby
# Add to your models
class Book < ApplicationRecord
  votable  # Can receive votes
end

class User < ApplicationRecord
  voter    # Can vote on other models
end

# Usage
@book.vote_up(@user)
@book.vote_down(@user, comment: 'Not helpful', feedback_option: 'unhelpful')

# Querying
@book.votes_count           # Total votes
@book.up_votes_count        # Up votes
@book.voted_by?(@user)      # Check if user voted
@book.voters                # All voters
Book.with_votes             # Books with votes

# Feedback options
@book.vote_up(@user, feedback_option: 'helpful')
@book.vote_down(@user, feedback_option: 'spam')
```

## Optional: JSON API Endpoints

If you need API endpoints for mobile apps or SPAs:

```bash
# Generate API configuration
rails generate thumbsy:api
```

This adds:

- RESTful JSON endpoints
- Authentication integration
- Authorization support
- Flexible routing

### API Routes

- `POST /:votable_type/:votable_id/vote_up` - Vote up
- `POST /:votable_type/:votable_id/vote_down` - Vote down
- `GET /:votable_type/:votable_id/vote` - Get vote status
- `DELETE /:votable_type/:votable_id/vote` - Remove vote

### API Usage

```bash
# Vote up on a post
curl -X POST /api/v1/books/1/vote_up \
  -H "Authorization: Bearer TOKEN" \
  -d '{"comment": "Great book!", "feedback_option": "helpful"}'

# Get vote status
curl -X GET /api/v1/books/1/vote \
  -H "Authorization: Bearer TOKEN"
```

### API Module Access

The `Thumbsy::Api` module is automatically available when you require the gem:

```ruby
require 'thumbsy'

# API module is immediately accessible
Thumbsy::Api.configure do |config|
  config.require_authentication = false
end

# Load full API functionality (controllers and routes)
Thumbsy.load_api!  # Call this in config/application.rb or an initializer
```

### API Configuration

```ruby
# config/initializers/thumbsy_api.rb
Thumbsy::Api.configure do |config|
  # Works with any authentication system
  config.authentication_method = proc do
    authenticate_user! # Your auth method
  end

  config.current_voter_method = proc do
    current_user # Your current user method
  end
end
```

## Core Features

✅ **ActiveRecord Integration**: Simple `votable` and `voter` declarations

✅ **Polymorphic Design**: Any model can vote on any other model

✅ **Comment Support**: Optional comments on every vote

✅ **Feedback Options**: Customizable feedback options (like, dislike, funny, etc.)

✅ **Rich Queries**: Comprehensive scopes and helper methods

✅ **Performance Optimized**: Proper database indexes

✅ **Optional API**: Add JSON endpoints only if needed

✅ **Flexible Authentication**: Works with Devise, JWT, API keys, etc.

✅ **Test Suite**: Complete RSpec tests included

✅ **Gem-Provided Model**: Model is provided directly by the gem for consistency

## Use Cases

### ActiveRecord Only

- Traditional Rails apps with server-rendered views
- Internal voting systems
- Simple like/dislike functionality
- Content moderation with feedback options

### With API

- Mobile applications
- Single Page Applications (SPAs)
- Microservices architecture
- Third-party integrations

## Documentation

- **Basic Usage**: This README
- **API Guide**: [docs/api-guide.md](docs/api-guide.md) - Complete API documentation and integration examples
- **Architecture Guide**: [docs/architecture-guide.md](docs/architecture-guide.md) - Technical details and design decisions

## Development & Testing

### Running Tests Locally

```bash
# Run the full test suite
bundle exec rspec

# Run tests with coverage report
COVERAGE=true bundle exec rspec

# Run specific test files
bundle exec rspec spec/thumbsy_spec.rb
bundle exec rspec spec/api_integration_spec.rb
```

### Testing Across Rails Versions

Thumbsy is tested against multiple Rails versions (7.1, 7.2, 8.0) and Ruby versions (3.3, 3.4):

```bash

RAILS_VERSION=8.0 bundle update rails
RAILS_VERSION=8.0 bundle exec rspec

# Use the automated test script
ruby script/test_rails_versions.rb
```

### Continuous Integration

Our CI pipeline automatically tests all supported combinations:

- **Ruby versions**: 3.3, 3.4
- **Rails versions**: 7.1, 7.2, 8.0
- **Total combinations**: 9 test matrices
- **Coverage requirement**: 78%+

All tests must pass across all combinations before any changes are merged.

### Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for your changes
4. Ensure all tests pass: `bundle exec rspec`
5. Test across Rails versions: `ruby script/test_rails_versions.rb`
6. Submit a pull request

## License

MIT
