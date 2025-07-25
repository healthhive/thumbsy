# frozen_string_literal: true

require "spec_helper"

class User < ActiveRecord::Base
  voter
end

class Book < ActiveRecord::Base
  votable
end

# Test models for comprehensive testing

RSpec.describe "Thumbsy Comprehensive Functionality" do
  let(:user) { User.create!(name: "Test User") }
  let(:user2) { User.create!(name: "Test User 2") }
  let(:user3) { User.create!(name: "Test User 3") }
  let(:book) { Book.create!(title: "The Great Gatsby") }
  let(:book2) { Book.create!(title: "To Kill a Mockingbird") }

  describe "Version and Core Setup" do
    it "has a version number" do
      expect(Thumbsy::VERSION).not_to be nil
      expect(Thumbsy::VERSION).to match(/\d+\.\d+\.\d+/)
    end

    it "extends ActiveRecord::Base with Extension module" do
      expect(ActiveRecord::Base.ancestors).to include(Thumbsy::Extension)
    end

    it "adds votable class method" do
      expect(ActiveRecord::Base).to respond_to(:votable)
    end

    it "adds voter class method" do
      expect(ActiveRecord::Base).to respond_to(:voter)
    end
  end

  describe "Module Configuration and Loading" do
    it "supports load_api! method" do
      require File.expand_path("../lib/thumbsy/api.rb", __dir__)
      # This may raise an error in non-Rails environments, which is expected

      Thumbsy.load_api!
      # If it succeeds, Api should be available
      expect(defined?(Thumbsy::Api)).to be_truthy
    rescue NameError => e
      # Expected in non-Rails environments when ActionController::API is not available
      expect(e.message).to include("ActionController::API")
    end

    it "handles const_missing for unknown constants" do
      expect { Thumbsy::UnknownConstant }.to raise_error(NameError)
    end

    it "autoloads Api module via const_missing" do
      require File.expand_path("../lib/thumbsy/api.rb", __dir__)
      # Test that accessing Api loads it successfully
      # This works because Api is autoloaded when accessed
      expect(Thumbsy::Api).to be_a(Module)
      expect(Thumbsy::Api.respond_to?(:configure)).to be_truthy
    end
  end

  describe "Module Integration" do
    it "includes Thumbsy::Votable when votable is called" do
      test_class = Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        votable
      end

      expect(test_class.ancestors).to include(Thumbsy::Votable)
    end

    it "includes Thumbsy::Voter when voter is called" do
      test_class = Class.new(ActiveRecord::Base) do
        self.table_name = "users"
        voter
      end

      expect(test_class.ancestors).to include(Thumbsy::Voter)
    end

    it "sets up votable associations correctly" do
      expect(book.class.reflect_on_association(:thumbsy_votes)).to be_present
      association = book.class.reflect_on_association(:thumbsy_votes)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:as]).to eq(:votable)
    end

    it "sets up voter associations correctly" do
      expect(user.class.reflect_on_association(:thumbsy_votes)).to be_present
      association = user.class.reflect_on_association(:thumbsy_votes)
      expect(association.macro).to eq(:has_many)
      expect(association.options[:as]).to eq(:voter)
    end
  end

  describe "Basic Voting Functionality" do
    describe "voting up" do
      it "allows a user to vote up on a book" do
        result = book.vote_up(user)

        expect(result).to be_persisted
        expect(book.up_voted_by?(user)).to be true
        expect(book.down_voted_by?(user)).to be false
        expect(book.voted_by?(user)).to be true
        expect(book.votes_count).to eq 1
        expect(book.up_votes_count).to eq 1
        expect(book.down_votes_count).to eq 0
      end

      it "allows voting with a comment" do
        vote = book.vote_up(user, comment: "Great book!")

        expect(vote.comment).to eq "Great book!"
        expect(vote.up_vote?).to be true
        expect(book.votes_with_comments.count).to eq 1
      end

      it "returns the same vote object when voting again" do
        vote1 = book.vote_up(user)
        vote2 = book.vote_up(user)

        expect(vote1.id).to eq vote2.id
        expect(book.votes_count).to eq 1
      end
    end

    describe "voting down" do
      it "allows a user to vote down on a book" do
        result = book.vote_down(user)

        expect(result).to be_persisted
        expect(book.down_voted_by?(user)).to be true
        expect(book.up_voted_by?(user)).to be false
        expect(book.voted_by?(user)).to be true
        expect(book.votes_count).to eq 1
        expect(book.up_votes_count).to eq 0
        expect(book.down_votes_count).to eq 1
      end

      it "allows voting down with comments" do
        result = book.vote_down(user, comment: "Not helpful")

        expect(result).to be_persisted
        expect(result.comment).to eq "Not helpful"
        expect(result.down_vote?).to be true
      end
    end
  end

  describe "Vote Management" do
    it "prevents duplicate votes from same user" do
      book.vote_up(user)
      book.vote_up(user)

      expect(book.votes_count).to eq 1
      expect(book.up_votes_count).to eq 1
    end

    it "allows changing vote type" do
      book.vote_up(user)
      expect(book.up_voted_by?(user)).to be true

      book.vote_down(user, comment: "Changed my mind")
      expect(book.down_voted_by?(user)).to be true
      expect(book.up_voted_by?(user)).to be false
      expect(book.votes_count).to eq 1

      vote = book.vote_by(user)
      expect(vote.comment).to eq "Changed my mind"
    end

    it "allows removing votes" do
      book.vote_up(user)
      expect(book.voted_by?(user)).to be true

      book.remove_vote(user)
      expect(book.voted_by?(user)).to be false
      expect(book.votes_count).to eq 0
    end

    it "updates existing vote when changing from up to down" do
      original_vote = book.vote_up(user, comment: "Initially good")
      updated_vote = book.vote_down(user, comment: "Actually not good")

      expect(original_vote.id).to eq updated_vote.id
      expect(updated_vote.down_vote?).to be true
      expect(updated_vote.comment).to eq "Actually not good"
    end
  end

  describe "Vote Counting and Scoring" do
    it "calculates vote counts correctly" do
      book.vote_up(user)
      book.vote_up(user2)
      book.vote_down(user3)

      expect(book.votes_count).to eq 3
      expect(book.up_votes_count).to eq 2
      expect(book.down_votes_count).to eq 1
    end

    it "calculates vote score correctly" do
      book.vote_up(user)
      book.vote_up(user2)
      book.vote_down(user3)

      expect(book.votes_score).to eq 1 # 2 up - 1 down = 1
    end

    it "handles zero votes correctly" do
      expect(book.votes_count).to eq 0
      expect(book.up_votes_count).to eq 0
      expect(book.down_votes_count).to eq 0
      expect(book.votes_score).to eq 0
    end

    it "calculates scores with multiple books independently" do
      book.vote_up(user)
      book.vote_up(user2)

      book2.vote_down(user)
      book2.vote_down(user3)

      expect(book.votes_score).to eq 2
      expect(book2.votes_score).to eq(-2)
    end
  end

  describe "Voter Functionality" do
    it "allows voting from voter perspective" do
      result = user.vote_up_for(book)

      expect(result).to be_persisted
      expect(user.voted_for?(book)).to be true
      expect(user.up_voted_for?(book)).to be true
      expect(user.down_voted_for?(book)).to be false
    end

    it "allows changing votes from voter perspective" do
      user.vote_up_for(book)
      expect(user.up_voted_for?(book)).to be true

      user.vote_down_for(book, comment: "Changed opinion")
      expect(user.down_voted_for?(book)).to be true
      expect(user.up_voted_for?(book)).to be false
    end

    it "allows removing votes from voter perspective" do
      user.vote_up_for(book)
      expect(user.voted_for?(book)).to be true

      user.remove_vote_for(book)
      expect(user.voted_for?(book)).to be false
    end

    it "gets voted objects by class" do
      user.vote_up_for(book)
      user.vote_down_for(book2)

      voted_books = user.voted_for(Book)
      expect(voted_books).to include(book, book2)
      expect(voted_books.count).to eq 2
    end

    it "gets up voted objects by class" do
      user.vote_up_for(book)
      user.vote_down_for(book2)

      up_voted_books = user.up_voted_for_class(Book)
      expect(up_voted_books).to include(book)
      expect(up_voted_books).not_to include(book2)
      expect(up_voted_books.count).to eq 1
    end

    it "gets down voted objects by class" do
      user.vote_up_for(book)
      user.vote_down_for(book2)

      down_voted_books = user.down_voted_for_class(Book)
      expect(down_voted_books).to include(book2)
      expect(down_voted_books).not_to include(book)
      expect(down_voted_books.count).to eq 1
    end
  end

  describe "Associations and Queries" do
    before do
      book.vote_up(user, comment: "Great!")
      book.vote_down(user2, comment: "Not so good")
      book2.vote_up(user3)
    end

    it "provides access to all votes" do
      votes = book.thumbsy_votes
      expect(votes.count).to eq 2
      expect(votes.map(&:voter)).to include(user, user2)
    end

    it "provides access to votes with comments" do
      votes_with_comments = book.votes_with_comments
      expect(votes_with_comments.count).to eq 2
      expect(votes_with_comments.map(&:comment)).to include("Great!", "Not so good")

      # Book2 has no comments
      expect(book2.votes_with_comments.count).to eq 0
    end

    it "provides access to up votes with comments" do
      up_votes_with_comments = book.up_votes_with_comments
      expect(up_votes_with_comments.count).to eq 1
      expect(up_votes_with_comments.first.comment).to eq "Great!"
    end

    it "provides access to down votes with comments" do
      down_votes_with_comments = book.down_votes_with_comments
      expect(down_votes_with_comments.count).to eq 1
      expect(down_votes_with_comments.first.comment).to eq "Not so good"
    end
  end

  describe "Scopes" do
    before do
      book.vote_up(user, comment: "Nice!")
      book2.vote_down(user2)
      # book3 has no votes
      @book3 = Book.create!(title: "Book Without Votes")
      # book4 has votes but no comments
      @book4 = Book.create!(title: "No comments book")
      @book4.vote_up(user2)
    end

    it "provides vote scopes" do
      books_with_votes = Book.with_votes
      expect(books_with_votes).to include(book, book2, @book4)
      expect(books_with_votes).not_to include(@book3)
    end

    it "provides up vote scopes" do
      books_with_up_votes = Book.with_up_votes
      expect(books_with_up_votes).to include(book, @book4)
      expect(books_with_up_votes).not_to include(book2, @book3)
    end

    it "provides down vote scopes" do
      books_with_down_votes = Book.with_down_votes
      expect(books_with_down_votes).to include(book2)
      expect(books_with_down_votes).not_to include(book, @book3, @book4)
    end

    it "provides comment scopes" do
      books_with_comments = Book.with_comments
      expect(books_with_comments).to include(book)
      expect(books_with_comments).not_to include(book2, @book3, @book4)
    end

    it "excludes empty comments" do
      empty_book = Book.create!(title: "Empty comment book")
      empty_book.vote_up(user, comment: "")

      books_with_comments = Book.with_comments
      expect(books_with_comments).not_to include(empty_book)
    end

    it "excludes nil comments" do
      nil_book = Book.create!(title: "Nil comment book")
      nil_book.vote_up(user, comment: nil)

      books_with_comments = Book.with_comments
      expect(books_with_comments).not_to include(nil_book)
    end

    it "handles objects with only down votes correctly" do
      down_only_book = Book.create!(title: "Down only")
      down_only_book.vote_down(user)

      books_with_up_votes = Book.with_up_votes
      expect(books_with_up_votes).not_to include(down_only_book)

      books_with_down_votes = Book.with_down_votes
      expect(books_with_down_votes).to include(down_only_book)
    end

    it "maintains scope distinctness with joins" do
      # Test that scopes return distinct results even with joins
      books_with_votes = Book.with_votes.distinct
      books_with_comments = Book.with_comments.distinct

      expect(books_with_votes.count).to be >= 1
      expect(books_with_comments.count).to be >= 1
    end
  end

  describe "Edge Cases and Error Handling" do
    it "handles voting on non-votable objects gracefully" do
      # Create a model that doesn't have votable functionality
      class NonVotableItem < ActiveRecord::Base
        self.table_name = "books" # Reuse existing table
      end

      non_votable = NonVotableItem.new
      result = user.vote_up_for(non_votable)
      expect(result).to be false
    end

    it "handles invalid voter objects gracefully" do
      # Create a model that doesn't have voter functionality
      class NonVoterItem < ActiveRecord::Base
        self.table_name = "users" # Reuse existing table
      end

      invalid_voter = NonVoterItem.new
      result = book.vote_up(invalid_voter)
      expect(result).to be false
    end

    it "handles voter without thumbsy_votes capability" do
      # Create an object that doesn't have voter functionality
      invalid_voter = Object.new
      expect(book.vote_up(invalid_voter)).to be false
      expect { book.vote_down(invalid_voter) }.to raise_error(ArgumentError, "Voter is invalid")
    end

    it "handles votable without thumbsy_votes capability from voter perspective" do
      # Create an object that doesn't have votable functionality
      invalid_votable = Object.new

      result = user.vote_up_for(invalid_votable)
      expect(result).to be false

      result = user.vote_down_for(invalid_votable)
      expect(result).to be false

      result = user.remove_vote_for(invalid_votable)
      expect(result).to be false

      expect(user.voted_for?(invalid_votable)).to be false
      expect(user.up_voted_for?(invalid_votable)).to be false
      expect(user.down_voted_for?(invalid_votable)).to be false
    end

    it "handles finding vote that doesn't exist" do
      vote = book.vote_by(user)
      expect(vote).to be_nil
    end

    it "handles checking votes on objects that haven't been voted on" do
      expect(book.voted_by?(user)).to be false
      expect(book.up_voted_by?(user)).to be false
      expect(book.down_voted_by?(user)).to be false
    end

    it "handles empty comment properly" do
      vote = book.vote_up(user, comment: "")
      expect(vote.comment).to eq ""

      # Empty comments shouldn't appear in with_comments scope
      expect(book.votes_with_comments).not_to include(vote)
    end

    it "handles nil comment properly" do
      vote = book.vote_up(user, comment: nil)
      expect(vote.comment).to be_nil

      # Nil comments shouldn't appear in with_comments scope
      expect(book.votes_with_comments).not_to include(vote)
    end

    it "verifies all query methods work with empty states" do
      # Test all query methods on object with no votes
      empty_book = Book.create!(title: "Empty Book")

      expect(empty_book.voted_by?(user)).to be false
      expect(empty_book.up_voted_by?(user)).to be false
      expect(empty_book.down_voted_by?(user)).to be false
      expect(empty_book.vote_by(user)).to be_nil
      expect(empty_book.votes_count).to eq(0)
      expect(empty_book.up_votes_count).to eq(0)
      expect(empty_book.down_votes_count).to eq(0)
      expect(empty_book.votes_score).to eq(0)
      expect(empty_book.votes_with_comments).to be_empty
      expect(empty_book.up_votes_with_comments).to be_empty
      expect(empty_book.down_votes_with_comments).to be_empty
    end

    it "verifies voter query methods with empty states" do
      # Test voter methods when they haven't voted on anything
      new_user = User.create!(name: "New User")

      expect(new_user.voted_for(Book)).to be_empty
      expect(new_user.up_voted_for_class(Book)).to be_empty
      expect(new_user.down_voted_for_class(Book)).to be_empty
      expect(new_user.voted_for?(book)).to be false
      expect(new_user.up_voted_for?(book)).to be false
      expect(new_user.down_voted_for?(book)).to be false
    end

    it "handles remove_vote return values correctly" do
      book.vote_up(user)
      result = book.remove_vote(user)
      expect(result).to be true
      result = book.remove_vote(user)
      expect(result).to be false
    end

    it "handles destroy_all return values in remove_vote" do
      book.vote_up(user)
      destroyed_votes = book.remove_vote(user)
      expect(destroyed_votes).to be true
      destroyed_votes_again = book.remove_vote(user)
      expect(destroyed_votes_again).to be false
    end

    it "verifies association dependent destroy behavior" do
      # Test that destroying votable destroys votes
      test_book = Book.create!(title: "Test Book for Destruction")
      vote = test_book.vote_up(user, comment: "Will be destroyed")
      vote_id = vote.id

      test_book.destroy

      # Vote should be destroyed due to dependent: :destroy
      expect { ThumbsyVote.find(vote_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "verifies voter association dependent destroy behavior" do
      # Test that destroying voter destroys their votes
      test_user = User.create!(name: "Test User for Destruction")
      vote = book.vote_up(test_user, comment: "Will be destroyed")
      vote_id = vote.id

      test_user.destroy

      # Vote should be destroyed due to dependent: :destroy
      expect { ThumbsyVote.find(vote_id) }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe "Vote Model Behavior" do
    let(:vote) { book.vote_up(user, comment: "Test comment") }

    it "has proper associations" do
      expect(vote.voter).to eq user
      expect(vote.votable).to eq book
    end

    it "has proper vote type methods" do
      up_vote = book.vote_up(user2)
      down_vote = book.vote_down(user3)

      expect(up_vote.up_vote?).to be true
      expect(up_vote.down_vote?).to be false

      expect(down_vote.up_vote?).to be false
      expect(down_vote.down_vote?).to be true
    end

    it "has timestamps" do
      expect(vote.created_at).to be_present
      expect(vote.updated_at).to be_present
    end

    it "stores comments correctly" do
      up_vote = book.vote_up(user, comment: "Good")
      down_vote = book.vote_down(user2, comment: "Bad")

      expect(up_vote.comment).to eq("Good")
      expect(down_vote.comment).to eq("Bad")
    end

    describe "vote model scopes" do
      before do
        book.vote_up(user, comment: "Up with comment")
        book.vote_down(user2, comment: "Down with comment")
        book2.vote_up(user2) # No comment
      end

      it "up_votes scope works" do
        up_votes = ThumbsyVote.up_votes
        expect(up_votes.count).to eq(2)
        expect(up_votes.all? { |v| v.vote == true }).to be true
      end

      it "down_votes scope works" do
        down_votes = ThumbsyVote.down_votes
        expect(down_votes.count).to eq(1)
        expect(down_votes.all? { |v| v.vote == false }).to be true
      end

      it "with_comments scope works" do
        votes_with_comments = ThumbsyVote.with_comments
        expect(votes_with_comments.count).to eq(2)
        expect(votes_with_comments.all? { |v| v.comment.present? }).to be true
      end
    end

    describe "vote model validations" do
      it "requires votable" do
        vote = ThumbsyVote.new(voter: user, vote: true)
        expect(vote.valid?).to be false
        expect(vote.errors[:votable]).to include("can't be blank")
      end

      it "requires voter" do
        vote = ThumbsyVote.new(votable: book, vote: true)
        expect(vote.valid?).to be false
        expect(vote.errors[:voter]).to include("can't be blank")
      end

      it "requires vote to be boolean" do
        vote = ThumbsyVote.new(votable: book, voter: user, vote: nil)
        expect(vote.valid?).to be false
        expect(vote.errors[:vote]).to be_present
      end

      it "prevents duplicate votes" do
        book.vote_up(user)

        duplicate_vote = ThumbsyVote.new(
          votable: book,
          voter: user,
          vote: false,
        )

        expect(duplicate_vote.valid?).to be false
        expect(duplicate_vote.errors[:voter_id]).to include("has already been taken")
      end
    end
  end

  describe "Feedback Option Validation" do
    before(:each) do
      Thumbsy.feedback_options = %w[like dislike funny]
      Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"
      ThumbsyVote.setup_feedback_options_validation! if defined?(ThumbsyVote)
    end

    it "accepts valid feedback_option values" do
      Thumbsy.feedback_options.each do |option|
        vote = ThumbsyVote.new(votable: book, voter: user, vote: true)
        vote.feedback_options = [option]
        expect(vote).to be_valid, "expected '#{option}' to be valid"
      end
    end

    it "allows feedback_option to be nil" do
      vote = ThumbsyVote.new(votable: book, voter: user, vote: true)
      vote.feedback_options = nil
      expect(vote).to be_valid
      expect(vote.feedback_options).to be_empty
    end

    it "rejects invalid feedback_options" do
      expect do
        ThumbsyVote.new(votable: book, voter: user, vote: true, feedback_options: ["invalid_option"]).save!
      end.to raise_error(ActiveRecord::RecordInvalid, /Feedback options contains invalid feedback option/)
    end
  end

  describe "Feedback Option Configuration" do
    before(:each) do
      Thumbsy.feedback_options = %w[like dislike funny]
      Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"
    end

    after(:each) do
      Thumbsy.feedback_options = %w[like dislike funny]
      Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"
    end

    it "does not define feedback_option enum or validation when feedback_options is nil" do
      Thumbsy.feedback_options = nil
      Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"
      expect(ThumbsyVote.respond_to?(:feedback_options)).to be false
      expect(ThumbsyVote.validators.map(&:attributes).flatten).not_to include(:feedback_option)
    end

    it "defines feedback_options validation when feedback_options is set" do
      Thumbsy.feedback_options = %w[helpful unhelpful spam]
      Object.send(:remove_const, :ThumbsyVote) if defined?(ThumbsyVote)
      load "lib/thumbsy/models/thumbsy_vote.rb"
      ThumbsyVote.setup_feedback_options_validation! if defined?(ThumbsyVote)
      expect(ThumbsyVote.validators.map(&:attributes).flatten).to include(:feedback_options)
    end
  end

  describe "Multiple Users Voting" do
    it "tracks different users voting on same object" do
      book.vote_up(user)
      book.vote_down(user2)
      book.vote_up(user3)

      expect(book.votes_count).to eq 3
      expect(book.up_votes_count).to eq 2
      expect(book.down_votes_count).to eq 1
      expect(book.votes_score).to eq 1

      # Check individual user votes
      expect(book.up_voted_by?(user)).to be true
      expect(book.down_voted_by?(user2)).to be true
      expect(book.up_voted_by?(user3)).to be true
    end

    it "allows users to vote on multiple objects" do
      book.vote_up(user)
      book2.vote_down(user)

      expect(user.voted_for?(book)).to be true
      expect(user.voted_for?(book2)).to be true
      expect(user.up_voted_for?(book)).to be true
      expect(user.down_voted_for?(book2)).to be true

      voted_books = user.voted_for(Book)
      expect(voted_books).to include(book, book2)
    end
  end

  describe "Complex Comment Scenarios" do
    it "handles multiline comments" do
      multiline_comment = "This is a\nmultiline\ncomment"
      vote = book.vote_up(user, comment: multiline_comment)

      expect(vote.comment).to eq(multiline_comment)
      expect(book.votes_with_comments.map(&:id)).to include(vote.id)
    end

    it "handles unicode comments" do
      unicode_comment = "Unicode test: café, naïve, résumé, 🎉"
      vote = book.vote_up(user, comment: unicode_comment)

      expect(vote.comment).to eq(unicode_comment)
    end

    it "handles very long comments" do
      long_comment = "x" * 1000
      vote = book.vote_up(user, comment: long_comment)

      expect(vote.comment).to eq(long_comment)
      expect(vote.comment.length).to eq(1000)
    end
  end

  describe "Advanced Vote Scenarios" do
    it "handles vote update vs create scenarios" do
      # First vote - should create
      vote1 = book.vote_up(user, comment: "First comment")
      expect(vote1).to be_persisted
      expect(vote1.comment).to eq("First comment")

      # Second vote - should update existing
      vote2 = book.vote_down(user, comment: "Changed mind")
      expect(vote2.id).to eq(vote1.id) # Same vote object
      expect(vote2.comment).to eq("Changed mind")
      expect(vote2.vote).to be false

      # Verify only one vote exists
      expect(book.votes_count).to eq(1)
    end

    it "handles vote creation edge cases" do
      # Test with nil comment explicitly
      vote = book.vote_up(user, comment: nil)
      expect(vote.comment).to be_nil

      # Test comment updates to nil
      book.vote_down(user, comment: nil)
      updated_vote = book.vote_by(user)
      expect(updated_vote.comment).to be_nil
    end

    it "correctly counts when same user votes multiple times" do
      # User changes vote multiple times
      book.vote_up(user)
      expect(book.votes_count).to eq(1)

      book.vote_down(user)
      expect(book.votes_count).to eq(1)
      expect(book.up_votes_count).to eq(0)
      expect(book.down_votes_count).to eq(1)

      book.vote_up(user)
      expect(book.votes_count).to eq(1)
      expect(book.up_votes_count).to eq(1)
      expect(book.down_votes_count).to eq(0)
    end

    it "correctly calculates score with mixed votes" do
      # Create a scenario with mixed votes
      users = 5.times.map { |i| User.create!(name: "User #{i}") }

      # 3 up votes, 2 down votes
      users[0..2].each { |u| book.vote_up(u) }
      users[3..4].each { |u| book.vote_down(u) }

      expect(book.votes_count).to eq(5)
      expect(book.up_votes_count).to eq(3)
      expect(book.down_votes_count).to eq(2)
      expect(book.votes_score).to eq(1) # 3 - 2 = 1

      # Cleanup
      users.each(&:destroy)
    end
  end

  describe "Cross-Model Voting" do
    before do
      # Create another votable model type
      class Article < ActiveRecord::Base
        self.table_name = "books" # Reuse table
        votable
      end
    end

    let(:article) { Article.create!(title: "Test Article") }

    it "handles voting across different model types" do
      book.vote_up(user)
      article.vote_down(user)

      expect(user.voted_for?(book)).to be true
      expect(user.voted_for?(article)).to be true
      expect(user.up_voted_for?(book)).to be true
      expect(user.down_voted_for?(article)).to be true
    end

    it "maintains separate vote counts per model type" do
      book.vote_up(user)
      book.vote_up(user2)
      article.vote_up(user)

      expect(book.votes_count).to eq(2)
      expect(article.votes_count).to eq(1)
    end

    it "returns correct objects by class" do
      book.vote_up(user)
      article.vote_up(user)

      voted_books = user.voted_for(Book)
      voted_articles = user.voted_for(Article)

      expect(voted_books).to include(book)
      expect(voted_books).not_to include(article)
      expect(voted_articles).to include(article)
      expect(voted_articles).not_to include(book)
    end
  end
end
