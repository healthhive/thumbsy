# Thumbsy API Guide

## Overview

The Thumbsy API provides RESTful JSON endpoints for voting functionality. The API is completely **optional** - you can use Thumbsy with just ActiveRecord methods for traditional Rails apps, or add the API when you need JSON endpoints for mobile apps, SPAs, or microservices.

## Installation Options

### Option 1: Core Only (ActiveRecord)

Perfect for traditional Rails apps with server-rendered views:

```bash
gem 'thumbsy'
bundle install
rails generate thumbsy:install --id_type=uuid  # or --id_type=bigint
rails db:migrate
```

Result: ~150 lines of code, ActiveRecord methods only

### Option 2: Core + API

For API-driven applications, mobile backends, or hybrid apps:

```bash
gem 'thumbsy'
bundle install
rails generate thumbsy:install --id_type=uuid  # or --id_type=bigint
rails generate thumbsy:api
rails db:migrate
```

Result: ~400 lines of code, ActiveRecord methods + JSON API endpoints

### ID Type Configuration

Choose the appropriate ID type for your application:

```bash
# UUID (default) - Best for distributed systems and APIs
rails generate thumbsy:install --id_type=uuid

# BIGINT - Recommended for high-volume traditional Rails apps
rails generate thumbsy:install --id_type=bigint
```

**API Considerations:**
- **UUID**: Provides better security in APIs (IDs are not sequential/guessable)
- **BIGINT**: Efficient for high-volume applications with numeric IDs
- **INTEGER**: Limited scalability, not recommended for production APIs

The ID type should match your existing models' primary key types for consistency.

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

## API Responses

### Success Response

```json
{
	"success": true,
	"data": {
		"id": 123,
		"vote_type": "up",
		"comment": "Great book!",
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

## Frontend Integration

### JavaScript API Client

```javascript
class VotingAPI {
	constructor(baseURL, token) {
		this.baseURL = baseURL;
		this.token = token;
	}

	async voteUp(type, id, comment = null) {
		return this.request("POST", `${type}/${id}/vote_up`, { comment });
	}

	async voteDown(type, id, comment = null) {
		return this.request("POST", `${type}/${id}/vote_down`, { comment });
	}

	async removeVote(type, id) {
		return this.request("DELETE", `${type}/${id}/vote`);
	}

	async getVoteStatus(type, id) {
		return this.request("GET", `${type}/${id}/vote`);
	}

	async getAllVotes(type, id) {
		return this.request("GET", `${type}/${id}/votes`);
	}

	async request(method, path, data = null) {
		const options = {
			method,
			headers: {
				Authorization: `Bearer ${this.token}`,
				"Content-Type": "application/json",
			},
		};

		if (data && method !== "GET") {
			options.body = JSON.stringify(data);
		}

		const response = await fetch(`${this.baseURL}/${path}`, options);
		return response.json();
	}
}

// Usage
const voting = new VotingAPI("/api/v1", "your-token-here");

// Vote up on a book
voting
	.voteUp("books", 123, "Great book!")
	.then((result) => console.log(result));

// Get vote status
voting.getVoteStatus("books", 123).then((status) => {
	console.log(`Voted: ${status.data.voted}`);
	console.log(`Score: ${status.data.vote_counts.score}`);
});
```

### React Component Example

```jsx
import { useState, useEffect } from "react";

function VotingButtons({ postType, postId, authToken }) {
	const [voteStatus, setVoteStatus] = useState(null);
	const [loading, setLoading] = useState(false);

	const voting = new VotingAPI("/api/v1", authToken);

	useEffect(() => {
		loadVoteStatus();
	}, [postId]);

	const loadVoteStatus = async () => {
		try {
			const result = await voting.getVoteStatus(postType, postId);
			setVoteStatus(result.data);
		} catch (error) {
			console.error("Failed to load vote status:", error);
		}
	};

	const handleVote = async (direction, comment = null) => {
		setLoading(true);

		try {
			if (direction === "up") {
				await voting.voteUp(postType, postId, comment);
			} else {
				await voting.voteDown(postType, postId, comment);
			}

			await loadVoteStatus();
		} catch (error) {
			console.error("Vote failed:", error);
		} finally {
			setLoading(false);
		}
	};

	const handleRemoveVote = async () => {
		setLoading(true);

		try {
			await voting.removeVote(postType, postId);
			await loadVoteStatus();
		} catch (error) {
			console.error("Remove vote failed:", error);
		} finally {
			setLoading(false);
		}
	};

	if (!voteStatus) return <div>Loading...</div>;

	const { voted, vote_type, vote_counts } = voteStatus;

	return (
		<div className="voting-buttons">
			<button
				onClick={() => handleVote("up")}
				disabled={loading}
				className={vote_type === "up" ? "active" : ""}
			>
				👍 {vote_counts.up}
			</button>

			<button
				onClick={() => handleVote("down")}
				disabled={loading}
				className={vote_type === "down" ? "active" : ""}
			>
				👎 {vote_counts.down}
			</button>

			{voted && (
				<button
					onClick={handleRemoveVote}
					disabled={loading}
					className="remove-vote"
				>
					Remove Vote
				</button>
			)}

			<span className="score">Score: {vote_counts.score}</span>

			<span className="total">Total: {vote_counts.total}</span>
		</div>
	);
}

export default VotingButtons;
```

### Mobile App Integration (Swift/iOS)

```swift
import Foundation

class VotingService {
    private let baseURL: String
    private let authToken: String

    init(baseURL: String, authToken: String) {
        self.baseURL = baseURL
        self.authToken = authToken
    }

    func voteUp(on resourceType: String, id: Int, comment: String? = nil) async throws -> VoteResponse {
        let url = URL(string: "\(baseURL)/\(resourceType)/\(id)/vote_up")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let comment = comment {
            let body = ["comment": comment]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(VoteResponse.self, from: data)
    }

    func getVoteStatus(for resourceType: String, id: Int) async throws -> VoteStatusResponse {
        let url = URL(string: "\(baseURL)/\(resourceType)/\(id)/vote")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(VoteStatusResponse.self, from: data)
    }
}

// Usage
let voting = VotingService(baseURL: "https://api.yourapp.com/v1", authToken: userToken)

Task {
    do {
        let result = try await voting.voteUp(on: "books", id: 123, comment: "Great book!")
        print("Vote successful: \(result)")
    } catch {
        print("Vote failed: \(error)")
    }
}
```

## Route Mounting

### Under API namespace

```ruby
# config/routes.rb
Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      mount Thumbsy::Api::Engine => "/", as: :voting
    end
  end
end

# Results in routes like: /api/v1/books/1/vote_up
```

### Custom path

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Thumbsy::Api::Engine => "/voting-api"
end

# Results in routes like: /voting-api/books/1/vote_up
```

## Custom Authorization Examples

### Content-based Authorization

```ruby
Thumbsy::Api.configure do |config|
  config.require_authorization = true
  config.authorization_method = proc do |votable, voter|
    case votable.class.name
    when "Book"
      votable.published? && !votable.archived? && !voter.banned?
    when "Comment"
      votable.book.published? && voter.can_vote?
    else
      true
    end
  end
end
```

### Role-based Authorization

```ruby
Thumbsy::Api.configure do |config|
  config.authorization_method = proc do |votable, voter|
    voter.has_role?(:voter) || voter.admin?
  end
end
```

## Error Handling

The API handles common errors gracefully:

- `404 Not Found` - Votable resource not found
- `401 Unauthorized` - Authentication required or failed
- `403 Forbidden` - Authorization failed
- `422 Unprocessable Entity` - Validation errors (duplicate vote, etc.)
- `400 Bad Request` - Invalid parameters

## Testing the API

### Using cURL

```bash
# Vote up
curl -X POST http://localhost:3000/api/v1/books/1/vote_up \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"comment": "Great book!"}'

# Vote down
curl -X POST http://localhost:3000/api/v1/books/1/vote_down \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"comment": "Not helpful"}'

# Get vote status
curl -X GET http://localhost:3000/api/v1/books/1/vote \
  -H "Authorization: Bearer YOUR_TOKEN"

# Remove vote
curl -X DELETE http://localhost:3000/api/v1/books/1/vote \
  -H "Authorization: Bearer YOUR_TOKEN"

# Get all votes
curl -X GET http://localhost:3000/api/v1/books/1/votes \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### RSpec Testing

```ruby
# spec/requests/voting_api_spec.rb
require "rails_helper"

RSpec.describe "Voting API", type: :request do
  let(:user) { User.create!(name: "Test User") }
  let(:book) { Book.create!(title: "Test Book") }
  let(:headers) { { "Authorization" => "Bearer #{user.token}" } }

  describe "POST /books/:id/vote_up" do
    it "creates an up vote" do
      post "/api/v1/books/#{book.id}/vote_up",
           params: { comment: "Great!" }.to_json,
           headers: headers.merge("Content-Type" => "application/json")

      expect(response).to have_http_status(:created)

      json = JSON.parse(response.body)
      expect(json["success"]).to be true
      expect(json["data"]["vote_type"]).to eq("up")
      expect(json["data"]["comment"]).to eq("Great!")
    end
  end

  describe "GET /books/:id/vote" do
    it "returns vote status" do
      book.vote_up(user, comment: "Nice!")

      get "/api/v1/books/#{book.id}/vote", headers: headers

      json = JSON.parse(response.body)
      expect(json["data"]["voted"]).to be true
      expect(json["data"]["vote_type"]).to eq("up")
      expect(json["data"]["vote_counts"]["total"]).to eq(1)
    end
  end

  describe "DELETE /books/:id/vote" do
    it "removes existing vote" do
      book.vote_up(user)

      delete "/api/v1/books/#{book.id}/vote", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end
  end
end

# Use included test helpers
include Thumbsy::ApiTestHelpers

# Test voting with helpers
response = vote_up(book, user, comment: "Great!")
expect(response["success"]).to be true

response = vote_down(book, user)
expect(response["data"]["vote_type"]).to eq("down")
```

## Migration from Core to API

If you start with just the core ActiveRecord functionality and later need API endpoints:

```bash
# Already have Thumbsy core installed
rails generate thumbsy:api
```

This adds the API functionality without breaking any existing code. Your ActiveRecord methods continue to work exactly as before, and you gain the JSON API endpoints.

## Benefits of Optional API Design

### 1. Start Simple

- Begin with ActiveRecord methods for traditional Rails views
- Add API endpoints only when needed (mobile app, SPA, etc.)
- No upfront complexity for simple use cases

### 2. Zero Breaking Changes

- Adding API functionality doesn't affect existing ActiveRecord usage
- Existing controllers and views continue working unchanged
- Gradual migration path available

### 3. Performance

- Core-only installation: ~150 lines of code
- Minimal memory footprint without API components
- API components loaded only when explicitly required

### 4. Flexibility

- Use traditional Rails patterns or modern API patterns
- Support multiple frontend types simultaneously
- Easy to extract voting to microservice later

The optional API design ensures Thumbsy grows with your application's needs while maintaining simplicity for basic use cases.
