class CreateFixPullRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :fix_pull_requests do |t|
      t.references :repository, null: false, foreign_key: true, index: false
      t.integer :number, null: false
      t.string :branch, null: false
      t.string :state, null: false, default: "open"
      t.string :ci_status
      t.string :head_sha
      t.datetime :opened_at, null: false
      t.datetime :merged_at
      t.datetime :closed_at

      t.timestamps
    end
    add_index :fix_pull_requests, %i[repository_id number], unique: true
    # At most one open Pitcrew PR per repo, even if two jobs race.
    add_index :fix_pull_requests, :repository_id, unique: true, where: "state = 'open'",
      name: "index_fix_pull_requests_one_open_per_repository"
  end
end
