class CreateRepositories < ActiveRecord::Migration[8.1]
  def change
    create_table :repositories do |t|
      t.bigint :github_id, null: false
      t.string :full_name, null: false
      t.string :default_branch, null: false, default: "main"
      t.bigint :installation_id, null: false
      t.boolean :enabled, null: false, default: false
      t.string :lockfile_sha
      t.string :ruby_version
      t.datetime :last_scanned_at

      t.timestamps
    end
    add_index :repositories, :github_id, unique: true
    add_index :repositories, :full_name, unique: true
  end
end
