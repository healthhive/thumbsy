# Thumbsy Architecture Guide

## Design Philosophy

Thumbsy follows the principle of **progressive enhancement** and **separation of concerns**:

- **Core functionality first**: ActiveRecord methods are always available and fully functional
- **Optional complexity**: API functionality is completely optional and opt-in
- **No breaking changes**: Adding features never breaks existing functionality
- **Clean separation**: Core and API components are architecturally isolated
- **Performance conscious**: Unused features don't impact performance
- **Rails conventions**: Follows Rails patterns and best practices
- **Gem-provided model**: The ThumbsyVote model is provided directly by the gem for consistency

## Architecture Overview

```
thumbsy/
├── lib/
│   └── thumbsy/
│       ├── votable.rb           # Votable concern
│       ├── voter.rb             # Voter concern
│       ├── engine.rb            # Rails engine for core
│       ├── api.rb               # API loader
│       ├── configuration.rb     # Core configuration
│       ├── version.rb           # Gem version
│       ├── extension.rb         # (optional) Extension hooks
│       ├── models/
│       │   └── thumbsy_vote.rb  # Gem-provided vote model
│       └── api/
│           ├── engine.rb        # API engine
│           ├── routes.rb        # API routes
│           ├── configuration.rb # API configuration
│           ├── controllers/
│           │   ├── application_controller.rb
│           │   └── votes_controller.rb
│           └── serializers/
│               └── vote_serializer.rb
│
├── lib/generators/
│   └── thumbsy/
│       ├── install_generator.rb # Core install generator
│       ├── api_generator.rb     # API generator
│       └── templates/
│           ├── create_thumbsy_votes.rb # Migration template
│           ├── thumbsy.rb              # Initializer template (used)
│           ├── thumbsy_api.rb          # Legacy API initializer template (not used for new installs)
│           └── README                  # Generator usage info
│
├── config/
│   └── initializers/
│       └── thumbsy.rb          # Centralized initializer (generated)
```

**Key Points:**
- The `ThumbsyVote` model is provided by the gem in `lib/thumbsy/models/thumbsy_vote.rb` and is not generated in your app.
- The API is organized under `lib/thumbsy/api/` with controllers, serializers, engine, routes, and configuration.
- There is no `test_helpers.rb` in the API directory.
- The generators are under `lib/generators/thumbsy/` with `install_generator.rb`, `api_generator.rb`, and a `templates/` directory.
- The `templates/` directory contains `thumbsy_api.rb` as a legacy template, but new installs use `thumbsy.rb` for the initializer and do not generate a separate `thumbsy_api.rb`.
- The initializer is always generated as `config/initializers/thumbsy.rb` and contains all configuration (core and API).

## Core Components

### 1. Votable Module

The `Thumbsy::Votable` module provides voting functionality for models that can receive votes:

```ruby
module Thumbsy::Votable
  extend ActiveSupport::Concern

  included do
    has_many :thumbsy_votes, as: :votable, class_name: "ThumbsyVote", dependent: :destroy
    scope :with_votes, -> { joins(:thumbsy_votes) }
    scope :with_up_votes, -> { joins(:thumbsy_votes).where(thumbsy_votes: { vote: true }) }
    scope :with_down_votes, -> { joins(:thumbsy_votes).where(thumbsy_votes: { vote: false }) }
    scope :with_comments, -> { joins(:thumbsy_votes).where.not(thumbsy_votes: { comment: [nil, ""] }) }
  end

  # Core voting methods
  def vote_up(voter, comment: nil, feedback_option: nil)
  def vote_down(voter, comment: nil, feedback_option: nil)
  def remove_vote(voter)

  # Query methods
  def voted_by?(voter)
  def up_voted_by?(voter)
  def down_voted_by?(voter)
  def vote_by(voter)

  # Count methods
  def votes_count
  def up_votes_count
  def down_votes_count
  def votes_score

  # Association methods
  def votes_with_comments
  def up_votes_with_comments
  def down_votes_with_comments
end
```

**Key Design Decisions:**

- Uses `thumbsy_votes` association name for clarity
- Polymorphic associations allow any model to be votable
- Methods delegate to the model's `vote_for` method for consistency
- Proper scoping prevents N+1 queries
- Graceful handling of invalid voters (returns false)

### 2. Voter Module

The `Thumbsy::Voter` module provides voting functionality for models that can cast votes:

```ruby
module Thumbsy::Voter
  extend ActiveSupport::Concern

  included do
    has_many :thumbsy_votes, as: :voter, class_name: "ThumbsyVote", dependent: :destroy
  end

  # Voting actions
  def vote_up_for(votable, comment: nil)
  def vote_down_for(votable, comment: nil)
  def remove_vote_for(votable)

  # Query methods
  def voted_for?(votable)
  def up_voted_for?(votable)
  def down_voted_for?(votable)

  # Association methods
  def voted_for(votable_class)
  def up_voted_for_class(votable_class)
  def down_voted_for_class(votable_class)
end
```

**Key Design Decisions:**

- Provides both directions: voter → votable and votable ← voter
- Consistent method naming patterns
- Efficient querying with proper associations
- Graceful handling of invalid votables (returns false)

### 3. Vote Model (Gem-Provided)

The core `ThumbsyVote` model is provided directly by the gem and handles the actual vote records:

```ruby
class ThumbsyVote < ActiveRecord::Base
  belongs_to :votable, polymorphic: true
  belongs_to :voter, polymorphic: true

  validates :votable, presence: true
  validates :voter, presence: true
  validates :vote, inclusion: { in: [true, false] }
  validates :voter_id, uniqueness: { scope: %i[voter_type votable_type votable_id] }

  FEEDBACK_OPTIONS = ['like', 'dislike', 'funny'].freeze

  enum :feedback_option, FEEDBACK_OPTIONS.each_with_index.to_h

  validates :feedback_option, inclusion: { in: FEEDBACK_OPTIONS }, allow_nil: true

  scope :up_votes, -> { where(vote: true) }
  scope :down_votes, -> { where(vote: false) }
  scope :with_comments, -> { where.not(comment: [nil, ""]) }

  def up_vote?
    vote == true
  end

  def down_vote?
    vote == false
  end

  def self.vote_for(votable, voter, vote_value, comment: nil, feedback_option: nil)
    raise ArgumentError, "Voter cannot be nil" if voter.nil?
    raise ArgumentError, "Votable cannot be nil" if votable.nil?

    existing_vote = find_by(
      votable: votable,
      voter: voter
    )

    if existing_vote
      existing_vote.update!(
        vote: vote_value,
        comment: comment,
        feedback_option: feedback_option
      )
      existing_vote
    else
      create!(
        votable: votable,
        voter: voter,
        vote: vote_value,
        comment: comment,
        feedback_option: feedback_option
      )
    end
  end
end
```

**Key Design Decisions:**

- **Model provided by gem**: The ThumbsyVote model is provided directly by the gem and is not generated from a template
- **Polymorphic design**: Allows maximum flexibility
- **Boolean vote field**: Simple true/false for up/down votes
- **Feedback options**: Customizable enum for additional vote metadata
- **Centralized logic**: `vote_for` class method handles all vote creation/updates
- **Proper validation**: Unique constraint prevents duplicate votes
- **Error handling**: Raises ArgumentError for nil voters/votables

## Generator System

### Install Generator

The `Thumbsy::Generators::InstallGenerator` sets up the core voting functionality:

- **Location:** `lib/generators/thumbsy/install_generator.rb`
- **Migration:** Generates `db/migrate/create_thumbsy_votes.rb` using the `create_thumbsy_votes.rb` template (with ERB variables for `id_type` and `feedback_options`).
- **Initializer:** Generates `config/initializers/thumbsy.rb` using the `thumbsy.rb` template. All Thumbsy and API configuration is centralized here.
- **No model is generated in your app.** The `ThumbsyVote` model is always provided by the gem in `lib/thumbsy/models/thumbsy_vote.rb`.

#### Usage

```bash
# Default (UUID primary keys, default feedback options)
rails generate thumbsy:install

# Custom feedback options
rails generate thumbsy:install --feedback=helpful,unhelpful,spam

# Custom ID type (bigint or integer)
rails generate thumbsy:install --id_type=bigint

# Both options
rails generate thumbsy:install --id_type=bigint --feedback=helpful,unhelpful,spam
```

#### Options

- `--feedback=option1,option2,...`  Set custom feedback options (default: like, dislike, funny)
- `--id_type=uuid|bigint|integer`   Set primary key type for the votes table (default: uuid)

#### Notes

- The initializer is always generated as `config/initializers/thumbsy.rb` and contains all configuration (core and API).
- The migration template uses ERB to inject the selected `id_type` and feedback options.
- No model file is generated in your app; the gem-provided model is always used.

## Optional API Architecture

### API Controllers

The API is built using Rails API controllers with a clean inheritance hierarchy:

```ruby
# Base controller with shared functionality
class Thumbsy::Api::ApplicationController < ActionController::API
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
class Thumbsy::Api::VotesController < Thumbsy::Api::ApplicationController
  before_action :find_votable

  def vote_up
    @vote = @votable.vote_up(current_voter, comment: vote_params[:comment], feedback_option: vote_params[:feedback_option])
    render json: success_response(@vote), status: :created
  end

  def vote_down
    @vote = @votable.vote_down(current_voter, comment: vote_params[:comment], feedback_option: vote_params[:feedback_option])
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

> **Note:** The actual migration template is generated and may use ERB for `id_type` and `feedback_options`.

```ruby
class CreateThumbsyVotes < ActiveRecord::Migration[7.0]
  def change
    create_table :thumbsy_votes, id: :uuid do |t| # id_type may be :uuid or :bigint
      t.references :votable, null: false, type: :uuid, polymorphic: true, index: false
      t.references :voter, null: false, type: :uuid, polymorphic: true, index: false
      t.boolean :vote, null: false, default: false
      t.text :comment
      t.integer :feedback_option # Only present if feedback_options are configured
      t.timestamps null: false
    end

    add_index :thumbsy_votes, [:votable_type, :votable_id, :voter_type, :voter_id],
      unique: true, name: "index_thumbsy_votes_on_voter_and_votable"
    add_index :thumbsy_votes, [:votable_type, :votable_id, :vote]
    add_index :thumbsy_votes, [:voter_type, :voter_id, :vote]
  end
end
```

### Votes Table (SQL)

```sql
CREATE TABLE thumbsy_votes (
  id uuid PRIMARY KEY,
  voter_type varchar(255) NOT NULL,
  voter_id uuid NOT NULL,
  votable_type varchar(255) NOT NULL,
  votable_id uuid NOT NULL,
  vote boolean NOT NULL DEFAULT false,
  comment text,
  feedback_option integer,
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL
);

-- Composite and unique indexes
CREATE UNIQUE INDEX index_thumbsy_votes_on_voter_and_votable
  ON thumbsy_votes (votable_type, votable_id, voter_type, voter_id);
CREATE INDEX index_thumbsy_votes_on_votable_type_votable_id_vote
  ON thumbsy_votes (votable_type, votable_id, vote);
CREATE INDEX index_thumbsy_votes_on_voter_type_voter_id_vote
  ON thumbsy_votes (voter_type, voter_id, vote);
```

**Schema Design Decisions:**

1. **Polymorphic Design**: `voter_type/voter_id` and `votable_type/votable_id` allow any model to participate
2. **Boolean Vote Field**: Simple `vote` boolean field for up/down votes
3. **Feedback Options**: Integer enum field for additional vote metadata
4. **Composite Indexes**: Optimize queries for both voter and votable lookups
5. **Unique Constraint**: Prevents duplicate votes at database level
6. **Optional Comments**: Text field for vote explanations
7. **Timestamps**: Track when votes were created/modified

## Performance Considerations

### Database Optimization

1. **Proper Indexing**:
   - Composite indexes on polymorphic keys
   - Vote boolean index for filtering
   - Unique index prevents duplicates and speeds up existence checks

2. **Query Optimization**:
   - Eager loading associations to prevent N+1 queries
   - Scoped queries for efficient filtering
   - Counter caches for high-traffic scenarios

3. **Association Efficiency**:

   ```ruby
   # Efficient vote counting
   def votes_count
     thumbsy_votes.count
   end

   # Cached vote counts (optional)
   def cached_votes_count
     Rails.cache.fetch("#{cache_key}/votes_count", expires_in: 1.hour) do
       thumbsy_votes.count
     end
   end
   ```

### Memory Usage

- **Core-only**: ~200 lines of code, minimal memory footprint
- **With API**: ~500 lines of code, additional controller classes
- **Lazy loading**: API components only loaded when explicitly required

### Scaling Considerations

1. **Database Partitioning**: Large vote tables can be partitioned by votable_type
2. **Caching**: Vote counts and status can be cached for heavy-traffic items
3. **Background Processing**: Vote notifications can be processed asynchronously
4. **Read Replicas**: Vote queries can be distributed to read-only replicas

## Testing Strategy

### Core Testing (Always)

```ruby
# spec/thumbsy_spec.rb
RSpec.describe Thumbsy do
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

    it 'handles feedback options' do
      vote = book.vote_up(user, feedback_option: 'like')
      expect(vote.feedback_option).to eq('like')
    end
  end
end
```

### API Testing (Optional)

```ruby
# spec/api_integration_spec.rb
RSpec.describe "Thumbsy API" do
  describe "POST /books/1/vote_up" do
    it "creates a vote via API" do
      post "/books/#{book.id}/vote_up", params: { comment: "Great book!", feedback_option: "like" }
      expect(response).to have_http_status(:created)
      expect(JSON.parse(response.body)["data"]["feedback_option"]).to eq("like")
    end
  end
end
