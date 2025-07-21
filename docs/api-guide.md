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

Configure the API in `config/initializers/thumbsy_api.rb`:

```ruby
Thumbsy::Api.configure do |config|
  # Authentication (required by default)
  config.require_authentication = true

  # Custom authentication method
  config.authentication_method = proc do
    authenticate_user! # Your auth method
  end

  # Set current voter
  config.current_voter_method = proc do
    current_user # Your current user method
  end

  # Authorization (optional)
  config.require_authorization = false
  config.authorization_method = proc do |votable, voter|
    # Return true/false for access
    votable.published? && !voter.banned?
  end

  # Custom voter serialization
  config.voter_serializer = proc do |voter|
    {
      id: voter.id,
      name: voter.name,
      avatar: voter.avatar.attached? ? rails_blob_url(voter.avatar) : nil
    }
  end
end
```

## Authentication Integration

### Devise Authentication

```ruby
Thumbsy::Api.configure do |config|
  config.authentication_method = proc do
    authenticate_user!
  end

  config.current_voter_method = proc do
    current_user
  end
end
```

### JWT Authentication

```ruby
Thumbsy::Api.configure do |config|
  config.authentication_method = proc do
    token = request.headers["Authorization"]&.split(" ")&.last

    begin
      decoded_token = JWT.decode(token, Rails.application.secret_key_base).first
      @current_user = User.find(decoded_token["user_id"])
    rescue JWT::DecodeError, ActiveRecord::RecordNotFound
      head :unauthorized
    end
  end

  config.current_voter_method = proc do
    @current_user
  end
end
```

### API Key Authentication

```ruby
Thumbsy::Api.configure do |config|
  config.authentication_method = proc do
    api_key = request.headers["X-API-Key"]
    @current_user = User.find_by(api_key: api_key)
    head :unauthorized unless @current_user&.active?
  end

  config.current_voter_method = proc do
    @current_user
  end
end
```

## API Request Parameters

### Vote Up/Down Parameters

```json
{
  "comment": "Great book!",
  "feedback_option": "like"
}
```

**Parameters:**
- `comment` (optional): Text comment explaining the vote
- `feedback_option` (optional): One of the configured feedback options (e.g., "like", "dislike", "funny")

### Feedback Options

Feedback options are customizable when generating the model:

```bash
# Default options (like, dislike, funny)
rails generate thumbsy:install

# Custom options
rails generate thumbsy:install --feedback=helpful,unhelpful,spam
```

## API Responses

### Success Response

```json
{
  "success": true,
  "data": {
    "id": 123,
    "vote": true,
    "comment": "Great book!",
    "feedback_option": "like",
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
  "success": true,
  "data": {
    "voted": true,
    "vote_type": "up",
    "comment": "Great book!",
    "feedback_option": "like",
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
  "success": false,
  "error": "Authentication required",
  "errors": {}
}
```

### Validation Error Response

```json
{
  "success": false,
  "error": "Validation failed",
  "errors": {
    "feedback_option": ["'invalid_option' is not a valid feedback_option"]
  }
}
```

## Frontend Integration

### JavaScript/TypeScript

```javascript
// Vote up with comment and feedback
const voteUp = async (votableType, votableId, comment, feedbackOption) => {
  const response = await fetch(`/api/v1/${votableType}/${votableId}/vote_up`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({
      comment: comment,
      feedback_option: feedbackOption
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

  const voteUp = async (comment, feedbackOption) => {
    try {
      const data = await voteUp(votableType, votableId, comment, feedbackOption);
      await fetchVoteStatus(); // Refresh status
      return data;
    } catch (error) {
      console.error('Failed to vote up:', error);
      throw error;
    }
  };

  const voteDown = async (comment, feedbackOption) => {
    try {
      const data = await voteDown(votableType, votableId, comment, feedbackOption);
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

  const voteUp = async (comment, feedbackOption) => {
    try {
      const data = await voteUp(votableType, votableId, comment, feedbackOption);
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

### Common Error Scenarios

1. **Authentication Required**
   ```json
   {
     "success": false,
     "error": "Authentication required"
   }
   ```

2. **Invalid Feedback Option**
   ```json
   {
     "success": false,
     "error": "Validation failed",
     "errors": {
       "feedback_option": ["'invalid_option' is not a valid feedback_option"]
     }
   }
   ```

3. **Resource Not Found**
   ```json
   {
     "success": false,
     "error": "Resource not found"
   }
   ```

4. **Authorization Failed**
   ```json
   {
     "success": false,
     "error": "Access denied"
   }
   ```

### Error Handling in Frontend

```javascript
const handleVote = async (action, comment, feedbackOption) => {
  try {
    setLoading(true);

    let response;
    if (action === 'up') {
      response = await voteUp(comment, feedbackOption);
    } else if (action === 'down') {
      response = await voteDown(comment, feedbackOption);
    } else if (action === 'remove') {
      response = await removeVote();
    }

    if (response.success) {
      // Handle success
      showSuccessMessage('Vote recorded successfully');
    } else {
      // Handle API error
      showErrorMessage(response.error);
    }
  } catch (error) {
    // Handle network/other errors
    if (error.response?.status === 401) {
      showErrorMessage('Please log in to vote');
    } else if (error.response?.status === 422) {
      const data = await error.response.json();
      showErrorMessage(data.errors?.feedback_option?.[0] || 'Invalid vote data');
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

- Validate feedback options against allowed values
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
    it "creates a vote with feedback option" do
      post "/books/#{book.id}/vote_up", params: {
        comment: "Great book!",
        feedback_option: "like"
      }

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json["data"]["feedback_option"]).to eq("like")
      expect(json["data"]["comment"]).to eq("Great book!")
    end

    it "rejects invalid feedback options" do
      post "/books/#{book.id}/vote_up", params: {
        feedback_option: "invalid"
      }

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]["feedback_option"]).to include("'invalid' is not a valid feedback_option")
    end
  end
end
```

This API guide provides comprehensive documentation for integrating Thumbsy's API endpoints into your applications, with support for the new feedback options feature.
