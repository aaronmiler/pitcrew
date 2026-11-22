class CreateFindings < ActiveRecord::Migration[8.1]
  def change
    create_table :findings do |t|
      t.references :repository, null: false, foreign_key: true, index: false
      t.references :advisory, null: false, foreign_key: true
      t.references :fix_pull_request, foreign_key: true
      t.string :locked_version, null: false
      t.string :status, null: false, default: "open"
      t.text :reason
      t.datetime :detected_at, null: false
      t.datetime :resolved_at

      t.timestamps
    end
    add_index :findings, %i[repository_id advisory_id], unique: true
    add_index :findings, :status
  end
end
