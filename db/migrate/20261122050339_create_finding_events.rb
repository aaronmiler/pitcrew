class CreateFindingEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :finding_events do |t|
      t.references :finding, null: false, foreign_key: true, index: false
      t.string :kind, null: false
      t.datetime :occurred_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end
    add_index :finding_events, %i[finding_id occurred_at]
    add_index :finding_events, %i[kind occurred_at]
  end
end
