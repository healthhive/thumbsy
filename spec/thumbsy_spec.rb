# frozen_string_literal: true

require "spec_helper"

# Test models for comprehensive testing
class User < ActiveRecord::Base
  voter
end

class Book < ActiveRecord::Base
  votable
end

RSpec.describe "Thumbsy Comprehensive Functionality" do
  let(:user) { User.create!(name: "Test User") }
  let(:user2) { User.create!(name: "Test User 2") }
  let(:user3) { User.create!(name: "Test User 3") }
  let(:book) { Book.create!(title: "The Great Gatsby") }
  let(:book2) { Book.create!(title: "To Kill a Mockingbird") }

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
    end

    it "provides vote scopes" do
      books_with_votes = Book.with_votes
      expect(books_with_votes).to include(book, book2)
      expect(books_with_votes).not_to include(@book3)
    end

    it "provides up vote scopes" do
      books_with_up_votes = Book.with_up_votes
      expect(books_with_up_votes).to include(book)
      expect(books_with_up_votes).not_to include(book2, @book3)
    end

    it "provides down vote scopes" do
      books_with_down_votes = Book.with_down_votes
      expect(books_with_down_votes).to include(book2)
      expect(books_with_down_votes).not_to include(book, @book3)
    end

    it "provides comment scopes" do
      books_with_comments = Book.with_comments
      expect(books_with_comments).to include(book)
      expect(books_with_comments).not_to include(book2, @book3)
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
end
