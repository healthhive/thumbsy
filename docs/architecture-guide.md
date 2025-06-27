# Thumbsy Architecture Guide

## Design Philosophy

Thumbsy follows the principle of **progressive enhancement** and **separation of concerns**:

- **Core functionality first**: ActiveRecord methods are always available and fully functional
- **Optional complexity**: API functionality is completely optional and opt-in
- **No breaking changes**: Adding features never breaks existing functionality
- **Clean separation**: Core and API components are architecturally isolated
- **Performance conscious**: Unused features don't impact performance
- **Rails conventions**: Follows Rails patterns and best practices

## Architecture Overview

```
thumbsy/
├── lib/thumbsy/           # Core functionality (always loaded)
│   ├── votable.rb         # ActiveRecord methods for votable models
│   ├── voter.rb           # ActiveRecord methods for voter models
│   ├── vote.rb            # Vote model definition
│   ├── engine.rb          # Basic Rails integration
│   └── version.rb         # Gem version
│
├── lib/thumbsy/api/       # Optional API (loaded on demand)
│   ├── controllers/       # API controllers
│   │   ├── base_controller.rb
│   │   └── votes_controller.rb
│   ├── engine.rb          # API routes and configuration
│   ├── configuration.rb   # API-specific configuration
│   └── test_helpers.rb    # API testing utilities
│
├── lib/generators/        # Rails generators
│   ├── thumbsy/
│   │   ├── install_generator.rb    # Core installation
│   │   └── api_generator.rb        # API installation
│   └── templates/         # Generator templates
│
└── app/                   # Rails app structure
    └── models/thumbsy/
        └── vote.rb        # Vote model implementation
```

## Core Components

### 1. Votable Module

The `Thumbsy::Votable` module provides voting functionality for models that can receive votes:

```ruby
module Thumbsy::Votable
  extend ActiveSupport::Concern

  included do
    has_many :received_votes, -> { order(:created_at) },
             as: :votable, class_name: 'Thumbsy::Vote', dependent: :destroy
    has_many :voters, -> { distinct }, through: :received_votes
  end

  # Core voting methods
  def vote_up(voter, comment: nil)
  def vote_down(voter, comment: nil)
  def remove_vote(voter)

  # Query methods
  def voted_by?(voter)
  def up_voted_by?(voter)
  def down_voted_by?(voter)

  # Count methods
  def votes_count
  def up_votes_count
  def down_votes_count
  def votes_score

  # Association methods
  def voters
  def up_voters
  def down_voters
  def votes_with_comments

  # Scopes
  scope :with_votes, -> { joins(:received_votes).distinct }
  scope :with_up_votes, -> { joins(:received_votes).where(thumbsy_votes: { vote_type: 'up' }).distinct }
end
```

**Key Design Decisions:**

- Uses `received_votes` association name to avoid conflicts
- Polymorphic associations allow any model to be votable
- Methods are defensive against duplicate votes
- Proper scoping prevents N+1 queries

### 2. Voter Module

The `Thumbsy::Voter` module provides voting functionality for models that can cast votes:

```ruby
module Thumbsy::Voter
  extend ActiveSupport::Concern

  included do
    has_many :votes, -> { order(:created_at) },
             as: :voter, class_name: 'Thumbsy::Vote', dependent: :destroy
  end

  # Voting actions
  def vote_up_on(votable, comment: nil)
  def vote_down_on(votable, comment: nil)
  def remove_vote_on(votable)

  # Query methods
  def voted_on?(votable)
  def up_voted_on?(votable)
  def down_voted_on?(votable)
  def vote_for(votable)

  # Association methods
  def votes
  def up_votes
  def down_votes
  def voted_items
end
```

**Key Design Decisions:**

- Provides both directions: voter → votable and votable ← voter
- Consistent method naming patterns
- Efficient querying with proper associations

### 3. Vote Model

The core `Thumbsy::Vote` model handles the actual vote records:

```ruby
class Thumbsy::Vote < ActiveRecord::Base
  self.table_name = 'thumbsy_votes'

  # Polymorphic associations
  belongs_to :voter, polymorphic: true
  belongs_to :votable, polymorphic: true

  # Validations
  validates :vote_type, inclusion: { in: %w[up down] }
  validates :voter, uniqueness: {
    scope: [:votable_type, :votable_id],
    message: 'has already voted on this item'
  }
  validates :voter_type, :voter_id, :votable_type, :votable_id, presence: true

  # Scopes
  scope :up_votes, -> { where(vote_type: 'up') }
  scope :down_votes, -> { where(vote_type: 'down') }
  scope :with_comments, -> { where.not(comment: [nil, '']) }

  # Instance methods
  def up_vote?
    vote_type == 'up'
  end

  def down_vote?
    vote_type == 'down'
  end
end
```

**Key Design Decisions:**

- Polymorphic design allows maximum flexibility
- Unique constraint prevents duplicate votes
- Simple vote_type field instead of separate boolean columns
- Optional comment support
- Proper validation and scoping

## Optional API Architecture

### API Controllers

The API is built using Rails API controllers with a clean inheritance hierarchy:

```ruby
# Base controller with shared functionality
class Thumbsy::Api::BaseController < ActionController::API
  before_action :authenticate_voter!
  before_action :authorize_voter!, if: :authorization_required?

  private

  def authenticate_voter!
    instance_eval(&Thumbsy::Api.configuration.authentication_method)
  end

  def current_voter
    @current_voter ||= instance_eval(&Thumbsy::Api.configuration.current_voter_method)
  end
end

# Votes controller handling all voting endpoints
class Thumbsy::Api::VotesController < Thumbsy::Api::BaseController
  before_action :find_votable

  def vote_up
    @vote = @votable.vote_up(current_voter, comment: vote_params[:comment])
    render json: success_response(@vote), status: :created
  end

  def vote_down
    @vote = @votable.vote_down(current_voter, comment: vote_params[:comment])
    render json: success_response(@vote), status: :created
  end

  def show
    render json: vote_status_response
  end

  def destroy
    @votable.remove_vote(current_voter)
    render json: { success: true }
  end
end
```

### Configuration System

The API uses a flexible configuration system:

```ruby
module Thumbsy::Api
  class Configuration
    attr_accessor :authentication_method, :current_voter_method,
                  :authorization_method, :voter_serializer,
                  :require_authentication, :require_authorization

    def initialize
      @require_authentication = true
      @require_authorization = false
      @authentication_method = -> { head :unauthorized }
      @current_voter_method = -> { nil }
      @voter_serializer = ->(voter) { { id: voter.id } }
    end
  end

  def self.configuration
    @configuration ||= Configuration.new
  end

  def self.configure
    yield(configuration)
  end
end
```

### Routing Engine

The API uses a Rails engine for clean route organization:

```ruby
Thumbsy::Api::Engine.routes.draw do
  concern :votable do
    member do
      post :vote_up
      post :vote_down
      delete :vote, action: :destroy
      get :vote, action: :show
      get :votes, action: :index
    end
  end

  # Dynamic routes for any votable type
  get ':votable_type/:id/vote', to: 'votes#show'
  post ':votable_type/:id/vote_up', to: 'votes#vote_up'
  post ':votable_type/:id/vote_down', to: 'votes#vote_down'
  delete ':votable_type/:id/vote', to: 'votes#destroy'
  get ':votable_type/:id/votes', to: 'votes#index'
end
```

## Database Schema

### Votes Table

```sql
CREATE TABLE thumbsy_votes (
  id bigint PRIMARY KEY AUTO_INCREMENT,
  voter_type varchar(255) NOT NULL,
  voter_id bigint NOT NULL,
  votable_type varchar(255) NOT NULL,
  votable_id bigint NOT NULL,
  vote_type varchar(10) NOT NULL,
  comment text,
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL,

  -- Performance indexes
  INDEX idx_thumbsy_votes_voter (voter_type, voter_id),
  INDEX idx_thumbsy_votes_votable (votable_type, votable_id),
  INDEX idx_thumbsy_votes_vote_type (vote_type),

  -- Unique constraint to prevent duplicate votes
  UNIQUE INDEX idx_thumbsy_unique_vote (voter_type, voter_id, votable_type, votable_id)
);
```

**Schema Design Decisions:**

1. **Polymorphic Design**: `voter_type/voter_id` and `votable_type/votable_id` allow any model to participate
2. **Composite Indexes**: Optimize queries for both voter and votable lookups
3. **Unique Constraint**: Prevents duplicate votes at database level
4. **Vote Type**: Single string column instead of separate boolean columns
5. **Optional Comments**: Text field for vote explanations
6. **Timestamps**: Track when votes were created/modified

### Migration Template

```ruby
class CreateThumbsyVotes < ActiveRecord::Migration[7.0]
  def change
    create_table :thumbsy_votes do |t|
      t.string :voter_type, null: false
      t.bigint :voter_id, null: false
      t.string :votable_type, null: false
      t.bigint :votable_id, null: false
      t.string :vote_type, null: false
      t.text :comment
      t.timestamps

      t.index [:voter_type, :voter_id], name: 'idx_thumbsy_votes_voter'
      t.index [:votable_type, :votable_id], name: 'idx_thumbsy_votes_votable'
      t.index :vote_type, name: 'idx_thumbsy_votes_vote_type'
      t.index [:voter_type, :voter_id, :votable_type, :votable_id],
              name: 'idx_thumbsy_unique_vote', unique: true
    end
  end
end
```

## Performance Considerations

### Database Optimization

1. **Proper Indexing**:
   - Composite indexes on polymorphic keys
   - Vote type index for filtering
   - Unique index prevents duplicates and speeds up existence checks

2. **Query Optimization**:
   - Eager loading associations to prevent N+1 queries
   - Scoped queries for efficient filtering
   - Counter caches for high-traffic scenarios

3. **Association Efficiency**:

   ```ruby
   # Efficient vote counting
   def votes_count
     received_votes.count
   end

   # Cached vote counts (optional)
   def cached_votes_count
     Rails.cache.fetch("#{cache_key}/votes_count", expires_in: 1.hour) do
       received_votes.count
     end
   end
   ```

### Memory Usage

- **Core-only**: ~150 lines of code, minimal memory footprint
- **With API**: ~400 lines of code, additional controller classes
- **Lazy loading**: API components only loaded when explicitly required

### Scaling Considerations

1. **Database Partitioning**: Large vote tables can be partitioned by votable_type
2. **Caching**: Vote counts and status can be cached for heavy-traffic items
3. **Background Processing**: Vote notifications can be processed asynchronously
4. **Read Replicas**: Vote queries can be distributed to read-only replicas

## Testing Strategy

### Core Testing (Always)

```ruby
# spec/models/thumbsy/votable_spec.rb
RSpec.describe Thumbsy::Votable do
  let(:user) { User.create!(name: "Test User") }
  let(:book) { Book.create!(title: "Test Book") }

  describe '#vote_up' do
    it 'creates an up vote' do
      expect { book.vote_up(user) }.to change { book.votes_count }.by(1)
      expect(book.up_voted_by?(user)).to be true
    end

    it 'prevents duplicate votes' do
      book.vote_up(user)
      expect { book.vote_up(user) }.not_to change { book.votes_count }
    end
  end

  describe '#votes_score' do
    it 'calculates correct score' do
      book.vote_up(User.create!(name: "User 1"))
      book.vote_up(User.create!(name: "User 2"))
      book.vote_down(User.create!(name: "User 3"))
      expect(book.votes_score).to eq(1)
    end
  end
end
```

### API Testing (Conditional)

```ruby
# spec/requests/thumbsy/api/votes_spec.rb
RSpec.describe 'Voting API', type: :request, if: defined?(Thumbsy::Api) do
  let(:user) { User.create!(name: "Test User") }
  let(:book) { Book.create!(title: "Test Book") }
  let(:headers) { { 'Authorization' => "Bearer #{user.token}" } }

  describe 'POST /:votable_type/:id/vote_up' do
    it 'creates vote via API' do
      post "/api/v1/books/#{book.id}/vote_up", headers: headers

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json['success']).to be true
      expect(json['data']['vote_type']).to eq('up')
    end
  end
end
```

### Integration Testing

```ruby
# spec/integration/thumbsy_integration_spec.rb
RSpec.describe 'Thumbsy Integration' do
  it 'works with both ActiveRecord and API' do
    # ActiveRecord usage
    book.vote_up(user, comment: 'Great!')
    expect(book.up_voted_by?(user)).to be true

    # API usage (if available)
    if defined?(Thumbsy::Api)
      get "/api/v1/books/#{book.id}/vote", headers: auth_headers
      json = JSON.parse(response.body)
      expect(json['data']['voted']).to be true
    end
  end
end
```

## Migration Paths

### Path 1: Traditional → API

**Step 1**: Start with ActiveRecord only

```bash
gem 'thumbsy'
rails generate thumbsy:install
rails db:migrate
```

**Step 2**: Build traditional Rails interface

```ruby
# app/controllers/books_controller.rb
def vote_up
  @book.vote_up(current_user)
  redirect_back(fallback_location: @book)
end

# app/views/books/show.html.erb
<%= link_to "👍 #{@book.up_votes_count}", vote_up_book_path(@book), method: :post %>
```

**Step 3**: Add API when needed

```bash
rails generate thumbsy:api
```

**Result**: Both traditional and API endpoints work simultaneously, no breaking changes.

### Path 2: API-First → Traditional

**Step 1**: Install everything

```bash
gem 'thumbsy'
rails generate thumbsy:install
rails generate thumbsy:api
rails db:migrate
```

**Step 2**: Build API first

```ruby
# API endpoints immediately available
# /api/v1/books/1/vote_up
```

**Step 3**: Add traditional views later

```ruby
# ActiveRecord methods available for traditional views
@book.vote_up(current_user)
```

### Path 3: Microservice Extraction

The API design makes it easy to extract voting to a separate service:

1. **Phase 1**: Use API internally
2. **Phase 2**: Extract API to separate Rails app
3. **Phase 3**: Original app calls voting service via HTTP

## Configuration Patterns

### Environment-Specific Configuration

```ruby
# config/initializers/thumbsy_api.rb
Thumbsy::Api.configure do |config|
  if Rails.env.development?
    config.require_authentication = false
  else
    config.authentication_method = proc { authenticate_user! }
    config.current_voter_method = proc { current_user }
  end
end
```

### Multi-Tenant Configuration

```ruby
Thumbsy::Api.configure do |config|
  config.authorization_method = proc do |votable, voter|
    votable.tenant_id == voter.tenant_id
  end
end
```

## Error Handling Strategy

### Graceful Degradation

```ruby
# If API is not loaded, fall back to ActiveRecord
def vote_via_api_or_fallback(votable, voter)
  if defined?(Thumbsy::Api)
    # Use API
    post "/api/v1/#{votable.class.name.downcase.pluralize}/#{votable.id}/vote_up"
  else
    # Use ActiveRecord
    votable.vote_up(voter)
  end
end
```

### Comprehensive Error Messages

```ruby
# API controllers provide detailed error information
rescue ActiveRecord::RecordInvalid => e
  render json: {
    success: false,
    error: 'Validation failed',
    errors: e.record.errors.full_messages
  }, status: :unprocessable_entity
```

This architecture provides maximum flexibility while maintaining performance and simplicity. The optional API design ensures that Thumbsy can grow with your application's needs without introducing unnecessary complexity upfront.
