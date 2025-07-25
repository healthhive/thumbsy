# Thumbsy API Guide

## Overview

The Thumbsy API provides RESTful JSON endpoints for voting functionality. The API is completely **optional** - you can use Thumbsy with just ActiveRecord methods for traditional Rails apps, or add the API when you need JSON endpoints for mobile apps, SPAs, or microservices.

## Installation Options

### Option 1: Core Only (ActiveRecord)

Perfect for traditional Rails apps with server-rendered views:

```bash
gem 'thumbsy'
bundle install
rails generate thumbsy:install # defaults to --id_type=uuid
rails db:migrate
```

Result: ~200 lines of code, ActiveRecord methods only

### Option 2: Core + API

For API-driven applications, mobile backends, or hybrid apps:

```bash
gem 'thumbsy'
bundle install
rails generate thumbsy:install # defaults to --id_type=uuid
rails generate thumbsy:api
rails db:migrate
```

Result: ~500 lines of code, ActiveRecord methods + JSON API endpoints

### ID Type Configuration

Choose the appropriate ID type for your application:

```bash
# Default ID type is UUID (recommended for distributed systems)
rails generate thumbsy:install

# BIGINT - Recommended for high-volume traditional Rails apps
rails generate thumbsy:install --id_type=bigint
```

## API Routes

### Voting Endpoints

All voting endpoints follow the pattern: `/:votable_type/:votable_id/...`

- `POST /:votable_type/:votable_id/vote_up` - Vote up
- `POST /:votable_type/:votable_id/vote_down` - Vote down
- `DELETE /:votable_type/:votable_id/vote` - Remove vote
- `GET /:votable_type/:votable_id/vote` - Get vote status
- `GET /:votable_type/:votable_id/votes` - Get all votes

### Route Examples

```
POST /books/1/vote_up
POST /comments/456/vote_down
DELETE /books/1/vote
GET /books/1/vote
GET /books/1/votes
```

## API Configuration

Configure the API and feedback_options in `config/initializers/thumbsy.rb` (centralized initializer):

```ruby
Thumbsy.configure do |config|
  config.feedback_options = %w[like dislike funny]

  config.api do |api|
    api.require_authentication = true
    api.authentication_method = proc do
      # ...
    end
    api.current_voter_method = proc do
      # ...
    end
  end
end
```

If you use the `--feedback` option with the installer, e.g.:

```sh
rails generate thumbsy:install --feedback=helpful,unhelpful,spam
```

The installer will generate an initializer with:

```ruby
Thumbsy.configure do |config|
  config.feedback_options = %w[helpful unhelpful spam]
end
```

**Note:**
- The API generator (`rails generate thumbsy:api`) will add `require 'thumbsy/api'` and `Thumbsy::Api.load!` to the top of `config/initializers/thumbsy.rb` if not already present, instead of creating a separate initializer.
- The `ThumbsyVote` model is provided by the gem and always uses the current value of `Thumbsy.feedback_options` for its enum and validation.

## Authentication Integration

All authentication options are set inside the `config.api` block in your `thumbsy.rb` initializer. Here are common patterns:

### Devise Authentication

```ruby
Thumbsy.configure do |config|
  # ...
  config.api do |api|
    api.authentication_method = proc do
      authenticate_user!
    end
    api.current_voter_method = proc do
      current_user
    end
  end
end
```

### JWT Authentication

```ruby
Thumbsy.configure do |config|
  # ...
  config.api do |api|
    api.authentication_method = proc do
      token = request.headers["Authorization"]&.split(" ")&.last
      begin
        decoded_token = JWT.decode(token, Rails.application.secret_key_base).first
        @current_user = User.find(decoded_token["user_id"])
      rescue JWT::DecodeError, ActiveRecord::RecordNotFound
        head :unauthorized
      end
    end
    api.current_voter_method = proc do
      @current_user
    end
  end
end
```

### API Key Authentication

```ruby
Thumbsy.configure do |config|
  # ...
  config.api do |api|
    api.authentication_method = proc do
      api_key = request.headers["X-API-Key"]
      @current_user = User.find_by(api_key: api_key)
      head :unauthorized unless @current_user&.active?
    end
    api.current_voter_method = proc do
      @current_user
    end
  end
end
```

## API Request Parameters

### Vote Up/Down Parameters

```json
{
  "comment": "Great book!",
  "feedback_options": ["like"]
}
```

**Parameters:**
- `comment` (optional): Text comment explaining the vote
- `feedback_options` (optional): One of the configured feedback_options (e.g., "like", "dislike", "funny")

## Feedback Options

- `feedback_options` is always a string key (e.g., "like", "dislike").
- The API and serializer will always return the string value for feedback_options.
- Invalid feedback_options will result in a validation error.

## API Responses

### Success Response

```json
{
  "data": {
    "id": 123,
    "vote": true,
    "comment": "Great book!",
    "feedback_options": ["like"],
    "voter": {
      "id": 456,
      "name": "John Doe",
      "avatar": "https://example.com/avatar.jpg"
    },
    "created_at": "2024-01-01T12:00:00Z",
    "updated_at": "2024-01-01T12:00:00Z"
  }
}
```

### Vote Status Response

```json
{
  "data": {
    "voted": true,
    "vote_type": "up",
    "comment": "Great book!",
    "feedback_options": ["like"],
    "vote_counts": {
      "total": 5,
      "up": 4,
      "down": 1,
      "score": 3
    }
  }
}
```

### Error Response

```json
{
  "message": "Error message",
  "errors": []
}
```

### Validation Error Response

```json
{
  "message": "Validation failed",
  "errors": ["'invalid_option' is not a valid feedback_options"]
}
```

## API Generator

- The API generator (`rails generate thumbsy:api`) will **not** create a separate initializer.
- It will add `require 'thumbsy/api'` and `Thumbsy::Api.load!` to the top of `config/initializers/thumbsy.rb` if not already present.
- All API and feedback configuration is centralized in `thumbsy.rb`.

## Frontend Integration

### JavaScript/TypeScript

```javascript
// Vote up with comment and feedback
const voteUp = async (votableType, votableId, comment, feedbackOptions) => {
  const response = await fetch(`/api/v1/${votableType}/${votableId}/vote_up`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      comment: comment,
      feedback_options: feedbackOptions
    })
  });

  const data = await response.json();
  return data;
};

// Get vote status
const getVoteStatus = async (votableType, votableId) => {
  const response = await fetch(`/api/v1/${votableType}/${votableId}/vote`, {
    headers: {
      'Authorization': `Bearer ${token}`
    }
  });

  const data = await response.json();
  return data;
};
```

### React Hook Example

```javascript
import { useState, useEffect } from 'react';

const useVote = (votableType, votableId) => {
  const [voteStatus, setVoteStatus] = useState(null);
  const [loading, setLoading] = useState(true);

  const fetchVoteStatus = async () => {
    try {
      const data = await getVoteStatus(votableType, votableId);
      setVoteStatus(data.data);
    } catch (error) {
      console.error('Failed to fetch vote status:', error);
    } finally {
      setLoading(false);
    }
  };

  const voteUp = async (comment, feedbackOptions) => {
    try {
      const data = await voteUp(votableType, votableId, comment, feedbackOptions);
      await fetchVoteStatus(); // Refresh status
      return data;
    } catch (error) {
      console.error('Failed to vote up:', error);
      throw error;
    }
  };

  const voteDown = async (comment, feedbackOptions) => {
    try {
      const data = await voteDown(votableType, votableId, comment, feedbackOptions);
      await fetchVoteStatus(); // Refresh status
      return data;
    } catch (error) {
      console.error('Failed to vote down:', error);
      throw error;
    }
  };

  const removeVote = async () => {
    try {
      await removeVote(votableType, votableId);
      await fetchVoteStatus(); // Refresh status
    } catch (error) {
      console.error('Failed to remove vote:', error);
      throw error;
    }
  };

  useEffect(() => {
    fetchVoteStatus();
  }, [votableType, votableId]);

  return {
    voteStatus,
    loading,
    voteUp,
    voteDown,
    removeVote
  };
};
```

### Vue.js Example

```javascript
// composables/useVote.js
import { ref, onMounted } from 'vue';

export function useVote(votableType, votableId) {
  const voteStatus = ref(null);
  const loading = ref(true);

  const fetchVoteStatus = async () => {
    try {
      const data = await getVoteStatus(votableType, votableId);
      voteStatus.value = data.data;
    } catch (error) {
      console.error('Failed to fetch vote status:', error);
    } finally {
      loading.value = false;
    }
  };

  const voteUp = async (comment, feedbackOptions) => {
    try {
      const data = await voteUp(votableType, votableId, comment, feedbackOptions);
      await fetchVoteStatus();
      return data;
    } catch (error) {
      console.error('Failed to vote up:', error);
      throw error;
    }
  };

  onMounted(() => {
    fetchVoteStatus();
  });

  return {
    voteStatus,
    loading,
    voteUp,
    voteDown,
    removeVote
  };
}
```

## Error Handling

### Response Format

All API responses follow a consistent format:

**Success Response:**
```json
{
  "data": { ... }
}
```

**Error Response:**
```json
{
  "message": "Error message",
  "errors": [...]
}
```

### Helper Methods

The Thumbsy API provides convenient helper methods for common HTTP status codes:

- `render_success(data, status)` - Renders success response (default status: 200)
- `render_error(message, status, errors)` - Renders error response (default status: 400)
- `render_unauthorized(message)` - Renders 401 Unauthorized
- `render_forbidden(message)` - Renders 403 Forbidden
- `render_not_found(exception)` - Renders 404 Not Found
- `render_unprocessable_entity(message, errors)` - Renders 422 Unprocessable Entity
- `render_bad_request(message)` - Renders 400 Bad Request

### Common Error Scenarios

1. **Authentication Required**
   ```json
   {
     "message": "Authentication required",
     "errors": []
   }
   ```

2. **Invalid Feedback Option**
   ```json
   {
     "message": "Validation failed",
     "errors": ["'invalid_option' is not a valid feedback_options"]
   }
   ```

3. **Resource Not Found**
   ```json
   {
     "message": "Resource not found",
     "errors": []
   }
   ```

4. **Authorization Failed**
   ```json
   {
     "message": "Access denied",
     "errors": []
   }
   ```

5. **Invalid Voter**
   ```json
   {
     "message": "Voter is invalid",
     "errors": []
   }
   ```

### Error Handling in Frontend

```javascript
const handleVote = async (action, comment, feedbackOptions) => {
  try {
    setLoading(true);

    let response;
    if (action === 'up') {
      response = await voteUp(comment, feedbackOptions);
    } else if (action === 'down') {
      response = await voteDown(comment, feedbackOptions);
    } else if (action === 'remove') {
      response = await removeVote();
    }

    if (response.data) {
      // Handle success
      showSuccessMessage('Vote recorded successfully');
    } else {
      // Handle API error
      showErrorMessage(response.message);
    }
  } catch (error) {
    // Handle network/other errors
    if (error.response?.status === 401) {
      showErrorMessage('Please log in to vote');
    } else if (error.response?.status === 422) {
      const data = await error.response.json();
      showErrorMessage(data.errors?.[0] || 'Invalid vote data');
    } else {
      showErrorMessage('Failed to record vote. Please try again.');
    }
  } finally {
    setLoading(false);
  }
};
```

## Performance Considerations

### Caching Strategies

1. **Vote Counts**: Cache vote counts for frequently accessed items
2. **User Vote Status**: Cache individual user vote status
3. **API Responses**: Use HTTP caching headers for vote status endpoints

### Database Optimization

- Proper indexes on polymorphic associations
- Efficient queries for vote counting
- Background processing for vote analytics

## Security Considerations

### Input Validation

- Validate feedback_options against allowed values
- Sanitize comment text
- Rate limiting for vote submissions

### Authorization

- Ensure users can only vote on accessible content
- Prevent vote manipulation through proper authentication
- Audit logging for vote changes

## Testing

### API Testing

```ruby
# spec/api_integration_spec.rb
RSpec.describe "Thumbsy API" do
  let(:user) { User.create!(name: "Test User") }
  let(:book) { Book.create!(title: "Test Book") }

  before do
    Thumbsy::Api.configure do |config|
      config.require_authentication = false
      config.current_voter_method = -> { user }
    end
  end

  describe "POST /books/:id/vote_up" do
    it "creates a vote with feedback_options" do
      post "/books/#{book.id}/vote_up", params: {
        comment: "Great book!",
        feedback_options: ["like"]
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["feedback_options"]).to eq(["like"])
      expect(json["data"]["comment"]).to eq("Great book!")
    end

    it "rejects invalid feedback_options" do
      post "/books/#{book.id}/vote_up", params: {
        feedback_options: ["invalid"]
      }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["message"]).to eq("Failed to create vote")
    end
  end
end
```

### Custom Controller Example

If you need to extend the Thumbsy API with custom endpoints, you can use the helper methods:

```ruby
# app/controllers/api/v1/custom_votes_controller.rb
class Api::V1::CustomVotesController < Thumbsy::Api::ApplicationController
  before_action :find_votable

  def bulk_vote
    votes_data = params[:votes]

    if votes_data.blank?
      return render_bad_request("Votes data is required")
    end

    results = []
    errors = []

    votes_data.each do |vote_data|
      begin
        vote = @votable.vote_up(current_voter,
                               comment: vote_data[:comment],
                               feedback_options: vote_data[:feedback_options])

        if vote && vote.persisted?
          results << { id: vote.id, status: "created" }
        else
          errors << { data: vote_data, error: "Failed to create vote" }
        end
      rescue => e
        errors << { data: vote_data, error: e.message }
      end
    end

    if errors.empty?
      render_success({ results: results, message: "All votes created successfully" })
    else
      error_messages = errors.map { |e| e[:error] }
      render_unprocessable_entity("Some votes failed", { errors: error_messages })
    end
  end

  private

  def find_votable
    votable_class = params[:votable_type].constantize
    @votable = votable_class.find(params[:votable_id])
  rescue NameError
    render_bad_request("Invalid votable type")
  rescue ActiveRecord::RecordNotFound
    render_not_found(nil)
  end
end
```

This API guide provides comprehensive documentation for integrating Thumbsy's API endpoints into your applications, with support for the new feedback options feature.
