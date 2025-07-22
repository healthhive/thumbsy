# frozen_string_literal: true

require "spec_helper"

class User < ActiveRecord::Base
  voter
end

class Book < ActiveRecord::Base
  votable
end

# Test models for edge case testing
class NonVotableItem < ActiveRecord::Base
  # No votable concern included
end

class NonVoterItem < ActiveRecord::Base
  # No voter concern included
end

RSpec.describe "Thumbsy Module Edge Cases" do
  let(:user) { User.create!(name: "Test User") }
  let(:user2) { User.create!(name: "Test User 2") }
  let(:book) { Book.create!(title: "Test Book") }
  let(:book2) { Book.create!(title: "Test Book 2") }
  let(:non_votable) { NonVotableItem.create! } # No name attribute
  let(:non_voter) { NonVoterItem.create! }     # No name attribute

  describe "Votable Module Edge Cases" do
    describe "vote_up method" do
      it "raises ArgumentError when voter is nil" do
        expect { book.vote_up(nil) }.to raise_error(ArgumentError)
      end

      it "handles voter without thumbsy_votes capability" do
        expect(book.vote_up(non_voter)).to be false
      end

      it "handles voter that doesn't respond to thumbsy_votes" do
        voter_without_association = double("voter")
        allow(voter_without_association).to receive(:respond_to?).with(:thumbsy_votes).and_return(false)

        expect(book.vote_up(voter_without_association)).to be false
      end

      it "handles voter that responds to thumbsy_votes but returns false" do
        # Create a real object that responds to thumbsy_votes but doesn't have the association
        voter_without_association = NonVoterItem.create!(name: "Test NonVoter")

        expect(book.vote_up(voter_without_association)).to be false
      end

      it "handles ActiveRecord::RecordInvalid exceptions" do
        # Mock ThumbsyVote.vote_for to raise an exception
        allow(ThumbsyVote).to receive(:vote_for).and_raise(ActiveRecord::RecordInvalid.new(ThumbsyVote.new))

        expect(book.vote_up(user)).to be false
      end

      it "handles very long comments" do
        long_comment = "a" * 10_000
        vote = book.vote_up(user, comment: long_comment)
        expect(vote).to be_persisted
        expect(vote.comment).to eq(long_comment)
      end

      it "handles unicode comments" do
        unicode_comment = "🌟 🚀 💯 这是一个测试评论"
        vote = book.vote_up(user, comment: unicode_comment)
        expect(vote).to be_persisted
        expect(vote.comment).to eq(unicode_comment)
      end

      it "handles multiline comments" do
        multiline_comment = "Line 1\nLine 2\nLine 3"
        vote = book.vote_up(user, comment: multiline_comment)
        expect(vote).to be_persisted
        expect(vote.comment).to eq(multiline_comment)
      end
    end

    describe "vote_down method" do
      it "raises ArgumentError when voter is nil" do
        expect { book.vote_down(nil) }.to raise_error(ArgumentError)
      end

      it "handles voter without thumbsy_votes capability" do
        expect(book.vote_down(non_voter)).to be false
      end

      it "handles ActiveRecord::RecordInvalid exceptions" do
        allow(ThumbsyVote).to receive(:vote_for).and_raise(ActiveRecord::RecordInvalid.new(ThumbsyVote.new))

        expect(book.vote_down(user)).to be false
      end
    end

    describe "remove_vote method" do
      it "handles nil voter gracefully" do
        expect(book.remove_vote(nil)).to be false
      end

      it "returns false when no vote exists to remove" do
        expect(book.remove_vote(user)).to be false
      end

      it "returns true when vote is successfully removed" do
        book.vote_up(user)
        expect(book.remove_vote(user)).to be true
      end

      it "handles multiple votes removal" do
        book.vote_up(user)
        book.vote_up(user2)
        expect(book.remove_vote(user)).to be true
        expect(book.remove_vote(user2)).to be true
      end
    end

    describe "voted_by? method" do
      it "handles nil voter gracefully" do
        expect(book.voted_by?(nil)).to be false
      end

      it "returns false for non-existent vote" do
        expect(book.voted_by?(user)).to be false
      end

      it "returns true for existing vote" do
        book.vote_up(user)
        expect(book.voted_by?(user)).to be true
      end
    end

    describe "up_voted_by? method" do
      it "handles nil voter gracefully" do
        expect(book.up_voted_by?(nil)).to be false
      end

      it "returns false for non-existent vote" do
        expect(book.up_voted_by?(user)).to be false
      end

      it "returns true for existing up vote" do
        book.vote_up(user)
        expect(book.up_voted_by?(user)).to be true
      end

      it "returns false for down vote" do
        book.vote_down(user)
        expect(book.up_voted_by?(user)).to be false
      end
    end

    describe "down_voted_by? method" do
      it "handles nil voter gracefully" do
        expect(book.down_voted_by?(nil)).to be false
      end

      it "returns false for non-existent vote" do
        expect(book.down_voted_by?(user)).to be false
      end

      it "returns true for existing down vote" do
        book.vote_down(user)
        expect(book.down_voted_by?(user)).to be true
      end

      it "returns false for up vote" do
        book.vote_up(user)
        expect(book.down_voted_by?(user)).to be false
      end
    end

    describe "vote_by method" do
      it "handles nil voter gracefully" do
        expect(book.vote_by(nil)).to be_nil
      end

      it "returns nil for non-existent vote" do
        expect(book.vote_by(user)).to be_nil
      end

      it "returns vote object for existing vote" do
        vote = book.vote_up(user)
        expect(book.vote_by(user).id).to eq(vote.id)
      end
    end

    describe "vote counting methods" do
      it "handles zero votes correctly" do
        expect(book.votes_count).to eq(0)
        expect(book.up_votes_count).to eq(0)
        expect(book.down_votes_count).to eq(0)
        expect(book.votes_score).to eq(0)
      end

      it "handles mixed vote types correctly" do
        book.vote_up(user)
        book.vote_up(user2)
        book.vote_down(User.create!(name: "User 3"))

        expect(book.votes_count).to eq(3)
        expect(book.up_votes_count).to eq(2)
        expect(book.down_votes_count).to eq(1)
        expect(book.votes_score).to eq(1)
      end

      it "handles negative scores correctly" do
        book.vote_down(user)
        book.vote_down(user2)
        book.vote_up(User.create!(name: "User 3"))

        expect(book.votes_score).to eq(-1)
      end
    end

    describe "comment-related methods" do
      it "handles votes with comments" do
        book.vote_up(user, comment: "Great book!")
        book.vote_up(user2) # No comment

        expect(book.votes_with_comments.count).to eq(1)
        expect(book.up_votes_with_comments.count).to eq(1)
        expect(book.down_votes_with_comments.count).to eq(0)
      end

      it "handles votes with nil comments" do
        book.vote_up(user, comment: nil)

        expect(book.votes_with_comments.count).to eq(0)
      end
    end

    describe "scopes" do
      it "handles with_votes scope" do
        book.vote_up(user)
        expect(Book.with_votes).to include(book)
        expect(Book.with_votes.count).to eq(1)
      end

      it "handles with_up_votes scope" do
        book.vote_up(user)
        book.vote_down(user2)
        expect(Book.with_up_votes).to include(book)
        expect(Book.with_up_votes.count).to eq(1)
      end

      it "handles with_down_votes scope" do
        book.vote_down(user)
        book.vote_up(user2)
        expect(Book.with_down_votes).to include(book)
        expect(Book.with_down_votes.count).to eq(1)
      end

      it "handles with_comments scope" do
        book.vote_up(user, comment: "Great!")
        book.vote_up(user2) # No comment
        expect(Book.with_comments).to include(book)
        expect(Book.with_comments.count).to eq(1)
      end
    end
  end

  describe "Voter Module Edge Cases" do
    describe "vote_up_for method" do
      it "handles nil votable gracefully" do
        expect(user.vote_up_for(nil)).to be false
      end

      it "handles votable without thumbsy_votes capability" do
        expect(user.vote_up_for(non_votable)).to be false
      end

      it "handles votable that doesn't respond to thumbsy_votes" do
        votable_without_association = double("votable")
        allow(votable_without_association).to receive(:respond_to?).with(:thumbsy_votes).and_return(false)

        expect(user.vote_up_for(votable_without_association)).to be false
      end

      it "handles votable that responds to thumbsy_votes but returns false" do
        votable_without_association = double("votable")
        allow(votable_without_association).to receive(:respond_to?).with(:thumbsy_votes).and_return(true)
        allow(votable_without_association).to receive(:vote_up).and_return(false)

        expect(user.vote_up_for(votable_without_association)).to be false
      end

      it "successfully votes up for valid votable" do
        result = user.vote_up_for(book)
        expect(result).to be_persisted
        expect(book.up_voted_by?(user)).to be true
      end
    end

    describe "vote_down_for method" do
      it "handles nil votable gracefully" do
        expect(user.vote_down_for(nil)).to be false
      end

      it "handles votable without thumbsy_votes capability" do
        expect(user.vote_down_for(non_votable)).to be false
      end

      it "successfully votes down for valid votable" do
        result = user.vote_down_for(book)
        expect(result).to be_persisted
        expect(book.down_voted_by?(user)).to be true
      end
    end

    describe "remove_vote_for method" do
      it "handles nil votable gracefully" do
        expect(user.remove_vote_for(nil)).to be false
      end

      it "handles votable without thumbsy_votes capability" do
        expect(user.remove_vote_for(non_votable)).to be false
      end

      it "successfully removes vote for valid votable" do
        user.vote_up_for(book)
        expect(user.remove_vote_for(book)).to be true
        expect(book.voted_by?(user)).to be false
      end
    end

    describe "voted_for? method" do
      it "handles nil votable gracefully" do
        expect(user.voted_for?(nil)).to be false
      end

      it "handles votable without thumbsy_votes capability" do
        expect(user.voted_for?(non_votable)).to be false
      end

      it "returns false for non-existent vote" do
        expect(user.voted_for?(book)).to be false
      end

      it "returns true for existing vote" do
        user.vote_up_for(book)
        expect(user.voted_for?(book)).to be true
      end
    end

    describe "up_voted_for? method" do
      it "handles nil votable gracefully" do
        expect(user.up_voted_for?(nil)).to be false
      end

      it "handles votable without thumbsy_votes capability" do
        expect(user.up_voted_for?(non_votable)).to be false
      end

      it "returns false for non-existent vote" do
        expect(user.up_voted_for?(book)).to be false
      end

      it "returns true for existing up vote" do
        user.vote_up_for(book)
        expect(user.up_voted_for?(book)).to be true
      end

      it "returns false for down vote" do
        user.vote_down_for(book)
        expect(user.up_voted_for?(book)).to be false
      end
    end

    describe "down_voted_for? method" do
      it "handles nil votable gracefully" do
        expect(user.down_voted_for?(nil)).to be false
      end

      it "handles votable without thumbsy_votes capability" do
        expect(user.down_voted_for?(non_votable)).to be false
      end

      it "returns false for non-existent vote" do
        expect(user.down_voted_for?(book)).to be false
      end

      it "returns true for existing down vote" do
        user.vote_down_for(book)
        expect(user.down_voted_for?(book)).to be true
      end

      it "returns false for up vote" do
        user.vote_up_for(book)
        expect(user.down_voted_for?(book)).to be false
      end
    end

    describe "voted_for method" do
      it "returns voted objects for valid class" do
        user.vote_up_for(book)
        user.vote_up_for(book2)

        voted_books = user.voted_for(Book)
        expect(voted_books).to include(book, book2)
        expect(voted_books.count).to eq(2)
      end

      it "handles multiple votable types" do
        user.vote_up_for(book)
        # Create another votable type
        class Article < ActiveRecord::Base
          votable
        end
        article = Article.create!(title: "Test Article")
        user.vote_up_for(article)

        expect(user.voted_for(Book)).to include(book)
        expect(user.voted_for(Article)).to include(article)
      end
    end

    describe "up_voted_for_class method" do
      it "returns up voted objects for valid class" do
        user.vote_up_for(book)
        user.vote_down_for(book2)

        up_voted_books = user.up_voted_for_class(Book)
        expect(up_voted_books).to include(book)
        expect(up_voted_books).not_to include(book2)
        expect(up_voted_books.count).to eq(1)
      end
    end

    describe "down_voted_for_class method" do
      it "returns down voted objects for valid class" do
        user.vote_down_for(book)
        user.vote_up_for(book2)

        down_voted_books = user.down_voted_for_class(Book)
        expect(down_voted_books).to include(book)
        expect(down_voted_books).not_to include(book2)
        expect(down_voted_books.count).to eq(1)
      end
    end
  end

  describe "Extension Module Edge Cases" do
    it "adds votable method to ActiveRecord::Base" do
      expect(ActiveRecord::Base).to respond_to(:votable)
    end

    it "adds voter method to ActiveRecord::Base" do
      expect(ActiveRecord::Base).to respond_to(:voter)
    end

    it "includes Votable concern when votable is called" do
      test_class = Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        votable
      end

      expect(test_class.ancestors).to include(Thumbsy::Votable)
    end

    it "includes Voter concern when voter is called" do
      test_class = Class.new(ActiveRecord::Base) do
        self.table_name = "users"
        voter
      end

      expect(test_class.ancestors).to include(Thumbsy::Voter)
    end

    it "handles votable with options" do
      test_class = Class.new(ActiveRecord::Base) do
        self.table_name = "books"
        votable(some_option: "value")
      end

      expect(test_class.ancestors).to include(Thumbsy::Votable)
    end

    it "handles voter with options" do
      test_class = Class.new(ActiveRecord::Base) do
        self.table_name = "users"
        voter(some_option: "value")
      end

      expect(test_class.ancestors).to include(Thumbsy::Voter)
    end
  end

  describe "Integration Edge Cases" do
    it "handles circular voting scenarios" do
      # User votes on book, then changes vote type multiple times
      user.vote_up_for(book)
      expect(book.up_voted_by?(user)).to be true

      user.vote_down_for(book)
      expect(book.down_voted_by?(user)).to be true
      expect(book.up_voted_by?(user)).to be false

      user.vote_up_for(book)
      expect(book.up_voted_by?(user)).to be true
      expect(book.down_voted_by?(user)).to be false
    end

    it "handles vote removal and re-voting" do
      user.vote_up_for(book)
      expect(book.voted_by?(user)).to be true

      user.remove_vote_for(book)
      expect(book.voted_by?(user)).to be false

      user.vote_down_for(book)
      expect(book.down_voted_by?(user)).to be true
    end

    it "handles multiple users voting on same object" do
      user.vote_up_for(book)
      user2.vote_down_for(book)

      expect(book.votes_count).to eq(2)
      expect(book.up_votes_count).to eq(1)
      expect(book.down_votes_count).to eq(1)
      expect(book.votes_score).to eq(0)
    end

    it "handles user voting on multiple objects" do
      user.vote_up_for(book)
      user.vote_down_for(book2)

      expect(user.voted_for(Book)).to include(book, book2)
      expect(user.up_voted_for_class(Book)).to include(book)
      expect(user.down_voted_for_class(Book)).to include(book2)
    end
  end
end
