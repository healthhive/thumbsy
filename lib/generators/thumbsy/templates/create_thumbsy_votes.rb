class CreateThumbsyVotes < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :thumbsy_votes do |t|
      t.references :votable, null: false, polymorphic: true, index: true
      t.references :voter, null: false, polymorphic: true, index: true
      t.boolean :vote, null: false
      t.text :comment

      t.timestamps null: false
    end

    add_index :thumbsy_votes, [:voter_type, :voter_id, :votable_type, :votable_id], 
              unique: true, name: "index_thumbsy_votes_on_voter_and_votable"
    add_index :thumbsy_votes, [:votable_type, :votable_id, :vote]
    add_index :thumbsy_votes, [:voter_type, :voter_id, :vote]
  end
end
