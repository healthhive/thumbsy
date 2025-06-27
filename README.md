# Thumbsy - Rails Voting Gem

[![CI](https://github.com/yourusername/thumbsy/workflows/CI/badge.svg)](https://github.com/yourusername/thumbsy/actions)

A Rails gem for adding thumbs up/down voting functionality with comments.
Includes optional JSON API endpoints.

**Note**: This library was created with Claude Sonnet 4, based on the requirements specified in ORIGINAL_PROMPT.txt

## Installation

```bash
gem 'thumbsy'
bundle install
```

## Basic Setup (ActiveRecord only)

```bash
# Generate migration and basic functionality
rails generate thumbsy:install
rails db:migrate
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
@book.vote_down(@user, comment: 'Not helpful')

# Querying
@book.votes_count           # Total votes
@book.up_votes_count        # Up votes
@book.voted_by?(@user)      # Check if user voted
@book.voters                # All voters
Book.with_votes             # Books with votes
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
  -d '{"comment": "Great book!"}'

# Get vote status
curl -X GET /api/v1/books/1/vote \
  -H "Authorization: Bearer TOKEN"
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
✅ **Rich Queries**: Comprehensive scopes and helper methods
✅ **Performance Optimized**: Proper database indexes
✅ **Optional API**: Add JSON endpoints only if needed
✅ **Flexible Authentication**: Works with Devise, JWT, API keys, etc.
✅ **Test Suite**: Complete RSpec tests included

## Use Cases

### ActiveRecord Only

- Traditional Rails apps with server-rendered views
- Internal voting systems
- Simple like/dislike functionality

### With API

- Mobile applications
- Single Page Applications (SPAs)
- Microservices architecture
- Third-party integrations

## Documentation

- **Basic Usage**: This README
- **API Guide**: [docs/api-guide.md](docs/api-guide.md) - Complete API documentation and integration examples
- **Architecture Guide**: [docs/architecture-guide.md](docs/architecture-guide.md) - Technical details and design decisions
- **Changelog**: [docs/changelog.md](docs/changelog.md) - Version history and updates

## License

MIT
