class CreateThumbsyVotes < ActiveRecord::Migration[<%= ActiveRecord::Migration.current_version %>]
  def change
    create_table :thumbsy_votes, id: :<%= @id_type %> do |t|
      t.references :votable, null: false, type: :<%= @id_type %>, polymorphic: true, index: false
      t.references :voter, null: false, type: :<%= @id_type %>, polymorphic: true, index: true
      t.boolean :vote, null: false
      t.text :comment

      t.timestamps null: false
    end

    add_index :thumbsy_votes, [:votable_type, :votable_id, :voter_type, :voter_id],
              unique: true, name: "index_thumbsy_votes_on_voter_and_votable"
  end
end
