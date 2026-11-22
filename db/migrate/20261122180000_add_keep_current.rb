class AddKeepCurrent < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :keep_current_gems, :string, array: true, null: false, default: []
    add_column :settings, :tooling_pr_title_template, :string, null: false, default: "chore(deps): update %{gems}"

    # name -> version from the default branch's Gemfile.lock, written by each scan
    add_column :repositories, :locked_versions, :jsonb, null: false, default: {}

    create_table :gem_releases do |t|
      t.string :name, null: false, index: { unique: true }
      t.string :version, null: false
      t.datetime :checked_at, null: false

      t.timestamps
    end

    create_table :gem_bumps do |t|
      t.references :repository, null: false, foreign_key: true
      t.references :fix_pull_request, null: false, foreign_key: true, index: false
      t.string :gem_name, null: false
      t.string :from_version, null: false
      t.string :to_version, null: false

      t.timestamps
    end
    add_index :gem_bumps, %i[fix_pull_request_id gem_name], unique: true
  end
end
