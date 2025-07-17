# Thumbsy Architecture Guide

## Design Philosophy

Thumbsy follows the principle of **progressive enhancement** and **separation of concerns**:

- **Core functionality first**: ActiveRecord methods are always available and fully functional
- **Optional complexity**: API functionality is completely optional and opt-in
- **No breaking changes**: Adding features never breaks existing functionality
- **Clean separation**: Core and API components are architecturally isolated
- **Performance conscious**: Unused features don't impact performance
- **Rails conventions**: Follows Rails patterns and best practices
- **Template-based**: Models generated from templates ensure consistency

## Architecture Overview

```
thumbsy/
├── lib/thumbsy/           # Core functionality (always loaded)
│   ├── votable.rb         # ActiveRecord methods for votable models
│   ├── voter.rb           # ActiveRecord methods for voter models
│   ├── engine.rb          # Basic Rails integration
│   └── version.rb         # Gem version
│
├── lib/thumbsy/api/       # Optional API (loaded on demand)
│   ├── controllers/       # API controllers
│   │   ├── application_controller.rb
│   │   └── votes_controller.rb
│   ├── engine.rb          # API routes and configuration
│   ├── routes.rb          # API routing
│   └── test_helpers.rb    # API testing utilities
│
├── lib/generators/        # Rails generators
│   ├── thumbsy/
│   │   ├── install_generator.rb    # Core installation
│   │   └── api_generator.rb        # API installation
│   └── templates/         # Generator templates
│       ├── create_thumbsy_votes.rb # Migration template
│       ├── thumbsy_vote.rb.tt      # Model template
│       └── thumbsy_api.rb          # API template
│
└── app/                   # Rails app structure (generated)
    └── models/
        └── thumbsy_vote.rb # Generated vote model (optional)
```

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

### 3. Vote Model (Template-Based)

The core `ThumbsyVote` model is generated from a template and handles the actual vote records:

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

- **Template-based generation**: Model is generated from `thumbsy_vote.rb.tt` template
- **Polymorphic design**: Allows maximum flexibility
- **Boolean vote field**: Simple true/false for up/down votes
- **Feedback options**: Customizable enum for additional vote metadata
- **Centralized logic**: `vote_for` class method handles all vote creation/updates
- **Proper validation**: Unique constraint prevents duplicate votes
- **Error handling**: Raises ArgumentError for nil voters/votables

## Generator System

### Install Generator

The `Thumbsy::Generators::InstallGenerator` creates the core voting functionality:

```ruby
class InstallGenerator < Rails::Generators::Base
  class_option :feedback, type: :array, default: %w[like dislike funny],
                          desc: "Feedback options for votes (e.g. --feedback like dislike funny)"

  def create_migration_file
    migration_template "create_thumbsy_votes.rb", "db/migrate/create_thumbsy_votes.rb"
  end

  def create_thumbsy_vote_model
    template "thumbsy_vote.rb.tt", "app/models/thumbsy_vote.rb", feedback_options: options[:feedback]
  end
end
```

**Key Features:**
- Customizable feedback options via `--feedback` flag
- Template-based model generation
- Proper migration with indexes

### Template System

The model template (`thumbsy_vote.rb.tt`) ensures consistency:

```erb
# frozen_string_literal: true

class ThumbsyVote < ActiveRecord::Base
  belongs_to :votable, polymorphic: true
  belongs_to :voter, polymorphic: true

  validates :votable, presence: true
  validates :voter, presence: true
  validates :vote, inclusion: { in: [true, false] }
  validates :voter_id, uniqueness: { scope: %i[voter_type votable_type votable_id] }

  FEEDBACK_OPTIONS = <%== feedback_options.map(&:inspect).join(', ') %>.freeze

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

```sql
CREATE TABLE thumbsy_votes (
  id bigint PRIMARY KEY AUTO_INCREMENT,
  voter_type varchar(255) NOT NULL,
  voter_id bigint NOT NULL,
  votable_type varchar(255) NOT NULL,
  votable_id bigint NOT NULL,
  vote boolean NOT NULL,
  comment text,
  feedback_option integer,
  created_at timestamp NOT NULL,
  updated_at timestamp NOT NULL,

  -- Performance indexes
  INDEX idx_thumbsy_votes_voter (voter_type, voter_id),
  INDEX idx_thumbsy_votes_votable (votable_type, votable_id),
  INDEX idx_thumbsy_votes_vote (vote),

  -- Unique constraint to prevent duplicate votes
  UNIQUE INDEX idx_thumbsy_unique_vote (voter_type, voter_id, votable_type, votable_id)
);
```

**Schema Design Decisions:**

1. **Polymorphic Design**: `voter_type/voter_id` and `votable_type/votable_id` allow any model to participate
2. **Boolean Vote Field**: Simple `vote` boolean field for up/down votes
3. **Feedback Options**: Integer enum field for additional vote metadata
4. **Composite Indexes**: Optimize queries for both voter and votable lookups
5. **Unique Constraint**: Prevents duplicate votes at database level
6. **Optional Comments**: Text field for vote explanations
7. **Timestamps**: Track when votes were created/modified

### Migration Template

```ruby
class CreateThumbsyVotes < ActiveRecord::Migration[7.0]
  def change
    create_table :thumbsy_votes do |t|
      t.references :votable, null: false, polymorphic: true, index: true
      t.references :voter, null: false, polymorphic: true, index: true
      t.boolean :vote, null: false
      t.text :comment
      t.integer :feedback_option
      t.timestamps null: false

      t.index %i[voter_type voter_id votable_type votable_id],
              unique: true, name: "index_thumbsy_votes_on_voter_and_votable"
      t.index %i[votable_type votable_id vote]
      t.index %i[voter_type voter_id vote]
    end
  end
end
```

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
```

### Test Model Generation

Tests use the same template system as production:

```ruby
# spec/spec_helper.rb
config.before(:suite) do
  # Dynamically generate ThumbsyVote model from template
  template_path = File.expand_path("../lib/generators/thumbsy/templates/thumbsy_vote.rb.tt", __dir__)
  template_content = File.read(template_path)
  feedback_options = %w[like dislike funny]

  model_code = template_content.gsub(
    '<%== feedback_options.map(&:inspect).join(\', \') %>',
    feedback_options.map(&:inspect).join(', ')
  )

  eval(model_code, TOPLEVEL_BINDING)
end
```

This ensures test models always match production models.
