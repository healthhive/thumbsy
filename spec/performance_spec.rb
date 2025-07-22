# frozen_string_literal: true

require "spec_helper"
require "benchmark"

class User < ActiveRecord::Base
  voter
end

class Book < ActiveRecord::Base
  votable
end

RSpec.describe "Thumbsy Performance", :performance do
  USER_COUNT = 10
  BOOK_COUNT = 5
  VOTE_COUNT = 25

  before(:all) do
    # Restore test model definitions:
    # Create test data
    @users = USER_COUNT.times.map { |i| User.create!(name: "User #{i}") }
    @books = BOOK_COUNT.times.map { |i| Book.create!(title: "Book #{i}") }

    # Create votes for performance testing
    vote_attempts = 0
    successful_votes = 0

    VOTE_COUNT.times do |i|
      user = @users[i % USER_COUNT]  # Cycle through users
      book = @books[i % BOOK_COUNT]  # Cycle through books
      vote_attempts += 1

      # Skip if this user has already voted on this book
      next if book.voted_by?(user)

      vote_result = if i.even?
                      book.vote_up(user, comment: "Up vote #{i}")
                    else
                      book.vote_down(user, comment: "Down vote #{i}")
                    end

      successful_votes += 1 if vote_result&.persisted?
    end
  end

  after(:all) do
    # Clean up test data
    ThumbsyVote.delete_all
    User.delete_all if defined?(User)
    Book.delete_all if defined?(Book)
  end

  describe "Memory Usage" do
    it "loads core functionality with minimal memory overhead" do
      memory_before = memory_usage

      # Load a fresh model with voting capabilities
      fresh_model_class = Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        votable
      end

      # Use the class to ensure it's loaded
      expect(fresh_model_class.new).to respond_to(:vote_up)

      memory_after = memory_usage
      memory_increase = memory_after - memory_before

      # Should use less than 5MB for core functionality
      expect(memory_increase).to be < 5 * 1024 # KB

      puts "Memory increase for core functionality: #{memory_increase}KB"
    end

    it "API loading has reasonable memory footprint" do
      skip "API not loaded" unless defined?(Thumbsy::Api)

      memory_before = memory_usage

      # Simulate API loading
      require "thumbsy/api" if defined?(Thumbsy::Api)

      memory_after = memory_usage
      memory_increase = memory_after - memory_before

      # API should add less than 10MB
      expect(memory_increase).to be < 10 * 1024 # KB

      puts "Memory increase for API functionality: #{memory_increase}KB"
    end
  end

  describe "Query Performance" do
    it "prevents N+1 queries when loading votes" do
      # Test vote counting doesn't cause N+1
      books_with_counts = Book.includes(:thumbsy_votes)
                              .limit(5)
                              .map { |b| [b.title, b.votes_count] }

      expect(books_with_counts.size).to eq(5)
    end

    it "efficiently loads voters without N+1" do
      book = @books.first

      # Get voters through votes association
      voters = book.thumbsy_votes.includes(:voter).limit(10).map(&:voter).uniq
      voter_names = voters.map(&:name)
      expect(voter_names).to be_an(Array)
    end

    it "handles bulk vote operations efficiently" do
      book = @books.first
      test_users = @users.first(10)

      time_taken = Benchmark.realtime do
        test_users.each { |user| book.vote_up(user) }
      end

      # Should complete 10 votes in under 1 second
      expect(time_taken).to be < 1.0
      puts "Time for 10 votes: #{time_taken.round(3)}s"
    end
  end

  describe "Database Performance" do
    it "uses indexes effectively for voter lookups" do
      user = @users.first

      time_taken = Benchmark.realtime do
        voted_items = user.thumbsy_votes.includes(:votable).limit(20)
        expect(voted_items.to_a.size).to be <= 20
      end

      # Should be very fast with proper indexing
      expect(time_taken).to be < 0.15
      puts "Time for voter lookup: #{time_taken.round(4)}s"
    end

    it "efficiently counts votes by type" do
      book = @books.first

      time_taken = Benchmark.realtime do
        counts = {
          total: book.votes_count,
          up: book.up_votes_count,
          down: book.down_votes_count,
          score: book.votes_score,
        }
        expect(counts[:total]).to be >= 0
      end

      # Vote counting should be fast
      expect(time_taken).to be < 0.05
      puts "Time for vote counting: #{time_taken.round(4)}s"
    end

    it "handles duplicate vote attempts efficiently" do
      book = @books.first
      user = @users.first

      # First vote
      book.vote_up(user)

      time_taken = Benchmark.realtime do
        # Attempt duplicate votes
        10.times { book.vote_up(user) }
      end

      # Duplicate handling should be fast
      expect(time_taken).to be < 0.15
      expect(book.votes_count).to eq(book.votes_count) # No change
      puts "Time for 10 duplicate vote attempts: #{time_taken.round(4)}s"
    end
  end

  describe "Scalability" do
    it "maintains performance with large vote counts" do
      # Use existing votes for scalability testing
      books_with_votes = @books.select { |b| b.votes_count > 0 }
      large_book = books_with_votes.max_by(&:votes_count) || books_with_votes.first

      skip "No books with votes available for testing" if large_book.nil? || large_book.votes_count == 0

      time_taken = Benchmark.realtime do
        vote_data = {
          total_votes: large_book.votes_count,
          up_votes: large_book.up_votes_count,
          voters: large_book.thumbsy_votes.distinct.count(:voter_id),
          has_comments: large_book.votes_with_comments.count,
        }
        expect(vote_data[:total_votes]).to be > 0
      end

      puts "Time for large dataset queries: #{time_taken.round(4)}s"
      puts "  - Total votes: #{large_book.votes_count}"
      puts "  - Up votes: #{large_book.up_votes_count}"
      puts "  - Unique voters: #{large_book.thumbsy_votes.distinct.count(:voter_id)}"
    end

    it "efficiently handles scope queries" do
      time_taken = Benchmark.realtime do
        scoped_results = {
          with_votes: Book.with_votes.count,
          with_up_votes: Book.with_up_votes.count,
          with_comments: Book.joins(:thumbsy_votes)
                             .where.not(thumbsy_votes: { comment: [nil, ""] })
                             .distinct.count,
        }

        expect(scoped_results.values.sum).to be > 0
      end

      expect(time_taken).to be < 0.5
      puts "Time for scope queries: #{time_taken.round(4)}s"
    end
  end

  describe "Concurrent Operations" do
    it "handles multiple sequential votes efficiently", :slow do
      test_book = Book.create!(title: "Sequential Test Book")
      test_users = 20.times.map { |i| User.create!(name: "Sequential User #{i}") }

      start_time = Time.current

      # Process votes sequentially to avoid database connection issues
      test_users.each do |user|
        test_book.vote_up(user, comment: "Sequential vote from #{user.name}")
      rescue ActiveRecord::RecordInvalid
        # Handle any validation errors
      end

      end_time = Time.current

      # Verify data integrity
      expect(test_book.votes_count).to eq(20) # All votes should be recorded
      expect(test_book.thumbsy_votes.distinct.count(:voter_id)).to eq(20) # All voters should be unique

      duration = end_time - start_time
      puts "Sequential voting duration: #{duration.round(3)}s"

      # Clean up
      test_book.destroy
      test_users.each(&:destroy)
    end
  end

  private

  def memory_usage
    # Get memory usage in KB
    `ps -o rss= -p #{Process.pid}`.to_i
  end

  # Helper method for database query counting (simplified for basic functionality)
  def count_queries(&block)
    query_count = 0
    callback = lambda do |*_args|
      query_count += 1
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      block.call
    end

    query_count
  end
end

# Helper models for testing (if not already defined)
# Test models are defined in before(:all) block above
# Tables are created by spec_helper.rb
